
## Helper functions

logMessages = (messages...) ->
    console.log '[GitHub diff highlighter]', messages...

longestCommonPrefix = (strings...) ->
    prefix = []
    firstString = strings[0]
    combinePrefix = => prefix.join('')

    if strings.length < 2
        return combinePrefix()

    for i in [0...firstString.length]
        for string in strings[1..]
            if string[i] != firstString[i]
                return combinePrefix()
        prefix.push firstString[i]

    return combinePrefix()

dropNonexisting = (array) ->
    (element for element in array when element?) || []

notEmpty = (array) ->
    if array.length > 0 then array else null

unique = (array) ->
    array.filter((value, index, self) -> self.indexOf(value) == index)


# An HTML tag that is being merged in with text and other HTML tags
class HtmlTag
    tagTypeRegex = /<(\/?)\s*(\w+).*?(\/?)\w*>/

    constructor: (@tag) ->
        match = tagTypeRegex.exec(@tag)
        @isClosing = (match[1] || null)?
        @tagType = match[2].toLowerCase()
        @isSelfContained = (match[3] || null)?

    isClosingTag: -> @isClosing
    isOpeningTag: -> !@isClosingTag() and !@isSelfContained
    canClose: (otherTag) -> @tagType == otherTag.tagType

    getText: -> @tag
    getClosingTagText: -> "</#{@tagType}>"


# A stack of HtmlTags to assist merging two strings of tags
class TagStack
    constructor: ->
        @tagStack = []

    addTag: (tag) ->
        if tag.isClosingTag()
            openingTag = @tagStack.pop()
            unless tag.canClose(openingTag) and openingTag.isOpeningTag()
                throw 'Tags do not match: ' + tag.tag + " cannot close " + openingTag.tag
        else
            @tagStack.push tag

    addTagFromStack: (tag, stack) ->
        tag.fromStack = stack
        @addTag tag

    calculateTagDepth: (index) -> @tagStack.length - index

    getPrematurelyClosedTagsIndex: (closingTag) ->
        if closingTag.isClosingTag() and @tagStack.length > 0
            for tag, i in @tagStack by -1
                if closingTag.canClose tag
                    return i
        return null

    getPrematurelyClosedTagsFromIndex: (index) ->
        return @tagStack.slice(index).reverse()

    getPrematurelyClosedTags: (tag, notEarlyStack, earlyStack) ->
        if tag.isClosingTag()
            earlyStackTagIndex = earlyStack.getPrematurelyClosedTagsIndex tag
            if earlyStackTagIndex?
                notEarlyStackTagIndex = notEarlyStack.getPrematurelyClosedTagsIndex tag
                if notEarlyStackTagIndex?
                    if earlyStack.calculateTagDepth(earlyStackTagIndex) >= notEarlyStack.calculateTagDepth(notEarlyStackTagIndex)
                       return earlyStack.getPrematurelyClosedTagsFromIndex earlyStackTagIndex
        return []


# Splits an HTML line into tags and text while tracking the current position
class HtmlLineSplitter
    constructor: (@line) ->
        @tagRegex = /(<[^>]*?>)|([^<]*)/g

        @advance()

    advance: ->
        @top = @tagRegex.exec(@line)

    getContent: -> @top[0] || null
    setContent: (content) -> @top[0] = content
    getTag: -> new HtmlTag(@getContent())

    popContent: (value) ->
        value = @getContent()
        @advance()
        value

    isTag:  -> (@top[1] || null)?
    isText: -> (@top[2] || null)?
    hasContent: -> @getContent()?
    isClosingTag: -> @isTag() and @getContent().indexOf('/') != -1

    removeTextPrefix: (prefix) ->
        previous = @getContent()
        if previous.length == prefix.length
            @advance()
        else
            @setContent previous.substr(prefix.length)

# merge two HTML strings that differ only by HTML tags
class LineMerger
    constructor: (highlightedLine, diffLine) ->
        @highlighted = new HtmlLineSplitter highlightedLine
        @diff = new HtmlLineSplitter diffLine
        @highlightedStack = new TagStack()
        @diffStack = new TagStack()
        @output = []

    appendPopped: (splitter) -> @output.push splitter.popContent()

    mergeTextIntoOutput: ->
        prefix = longestCommonPrefix(@highlighted.getContent(), @diff.getContent())

        if prefix.length > 0
            @output.push prefix
            @highlighted.removeTextPrefix prefix
            @diff.removeTextPrefix prefix
        else
            throw 'Could not find prefix:\n' + @highlighted.getContent() + '\n' + @diff.getContent() + '\n'

    mergeTagIntoOutput: (splitter, stack) ->
        otherStack = if stack isnt @diffStack then @diffStack else @highlightedStack
        tag = splitter.getTag()
        prematurelyClosedTags = stack.getPrematurelyClosedTags tag, stack, otherStack

        stack.addTag(tag)

        @output.push t.getClosingTagText() for t in prematurelyClosedTags
        if tag.tagType == 'br'
            splitter.popContent()
        else
            @appendPopped(splitter)
        @output.push t.getText() for t in prematurelyClosedTags

    combineIntoHtml: ->
        while @highlighted.hasContent() or @diff.hasContent()
            # merge tags in before anything else
            if @highlighted.isTag()
                @mergeTagIntoOutput @highlighted, @highlightedStack
            else if @diff.isTag()
                @mergeTagIntoOutput @diff, @diffStack
            # merge in text common to both stacks
            else if @highlighted.isText() and @diff.isText()
                @mergeTextIntoOutput()
            # dump the rest in at the end
            else if @highlighted.hasContent()
                @appendPopped(@highlighted)
            else if @diff.hasContent()
                @appendPopped(@diff)

        @output.join('')


# A text file made of Lines
class File
    constructor: (@path) ->
        @lines = []

    storeLine: (lineElement, line, lineNumber) ->
        line = new Line(lineElement, line, lineNumber)
        @lines[lineNumber] = line
        line

    storeDiffLine: (lineElement, line, lineNumberPrevious, lineNumberCurrent) ->
        storedLine = new Line(lineElement, line, lineNumberCurrent || lineNumberPrevious)
        storedLine.setIsDiff lineNumberPrevious
        @lines.push storedLine
        storedLine

    getLine: (index) -> @lines[index]


# A line in a text file
class Line
    nonBreakingSpaceRegex = /&nbsp;/g
    constructor: (@lineElement, @line, @lineNumber) ->
        @diffMarker = ''

    setIsDiff: (@lineNumberPrevious)->
        @line = @line.replace(nonBreakingSpaceRegex, ' ')
        @diffMarker = @line.substr(0, 1)
        @line = @line.substr(1)

    diffAdded: -> @diffMarker == '+'
    diffRemoved: -> @diffMarker == '-'
    diffUnchanged: -> !@diffAdded() && !@diffRemoved() && @diffMarker != '@'


# Fetches, stores, and highlights diffs on a GitHub page
class DiffProcessor
    currentRepoPath = window.location.pathname.match(/\/[^\/]*\/[^\/]*\//)[0]
    endsInShaRegex = /[0-9a-fA-F]{40}$/

    constructor: ->
        @currentCommitIdentifier = @getGuessAtCurrentCommitIdentifier()
        @parentCommitIdentifiers = @getParentCommitIdentifiers()
        console.log @parentCommitIdentifiers
        @changedFilePaths = @getChangedFilePaths()
        @inlineChangedFilePaths = @getInlineChangedFilePaths()
        @diffData = @getRegularDiffData()
        @inlineDiffData = @getInlineDiffData()
        @parentData = {}
        @currentData = {}
        @numPagesToFetchBeforeProcessing = (@parentCommitIdentifiers.length + [@currentCommitIdentifier].length) * @changedFilePaths.length
        @registeredModifiedEventHandler = false
        console.log this


    getMergingBranchCommitIdentifier: (index) ->
        element = document.querySelectorAll('#js-discussion-header .gh-header-meta span.commit-ref.current-branch span')[index] ||
            document.querySelectorAll('.branch-name span.js-selectable-text')[index]
        element.innerText?.trim()

    getGuessAtCurrentCommitIdentifier: ->
        result = @getMergingBranchFromFromComment()
        result ||= document.body.querySelector('.commandbar input')?.getAttribute('data-branch')
        result ||= document.body.innerHTML.match(/commit\/([a-f0-9]{40})/)[1]
        result || @getMergingBranchCommitIdentifier 1

    getMergingBranchFromFromComment: ->
        result = /head sha1: &quot;([0-9a-fA-F]{40})&quot;/.exec(document.body.innerHTML)?[1]
    getMergingBranchToFromComment: ->
        result = /base sha1: &quot;([0-9a-fA-F]{40})&quot;/.exec(document.body.innerHTML)?[1]

    getMergingBranchTo: -> @getMergingBranchToFromComment()
    getMergingBranchFrom: -> @getMergingBranchFromFromComment()

    getParentCommitIdentifiers: ->
        notEmpty(dropNonexisting([@getMergingBranchTo()])) ||
        notEmpty(endsInShaRegex.exec(e.href)?[0] for e in document.querySelectorAll('.commit-meta .sha-block a.sha')) ||
        dropNonexisting([@getMergingBranchCommitIdentifier 0])

    getChangedFilePaths: ->
        changedFileLinks = document.querySelectorAll('.file .info span.js-selectable-text')
        for link in changedFileLinks
            path = link.innerText.trim()
            if path.indexOf('→') != -1
                path = link.parentElement?.parentElement?.getAttribute('data-path')
            path

    getInlineChangedFilePaths: ->
        e.getAttribute('data-path') for e in document.querySelectorAll('.inline-review-comment .box-header')

    getLinesToMerge: (filePath, line) ->
        if line.diffAdded() or line.diffUnchanged()
            dropNonexisting [@currentData[filePath].getLine(line.lineNumber)]
        else if line.diffRemoved()
            dropNonexisting (@parentData[id]?[filePath]?.getLine(line.lineNumberPrevious) for id in @parentCommitIdentifiers)
        else
            []

    highlightWhenDataReady: ->
        if @numPagesToFetchBeforeProcessing > 0
            return

        console.log 'ready to go!'
        console.log this

        @highlightDiffData @inlineDiffData
        @highlightDiffData @diffData

        unless @registeredModifiedEventHandler
            @registeredModifiedEventHandler = true
            document.addEventListener('DOMNodeInserted', =>
                @bucketMultipleEvents @refreshDataAndHighlight
            , false, true)

            setTimeout(@refreshDataAndHighlight, 2000)

    refreshDataAndHighlight: =>
        @diffData = @getRegularDiffData()
        @inlineDiffData = @getInlineDiffData()
        @highlightWhenDataReady()

    bucketMultipleEvents: (callback) =>
        @changeLastTriggered = new Date()
        setTimeout(=>
            if (new Date() - @changeLastTriggered) >= 100
                callback()
        , 100)

    highlightDiffData: (diffData) ->
        for filePath, fileList of diffData
            for file in fileList
                for _, line of file.lines
                    if line.lineElement.getAttribute('github-diff-highlighter-highlighted')?
                        continue
                    for mergeLine in @getLinesToMerge filePath, line
                        try
                            mergeLineText = mergeLine.line.replace /&nbsp;/g, ' '
                            line.lineElement.innerHTML = line.diffMarker + new LineMerger(line.line, mergeLineText).combineIntoHtml()
                            line.lineElement.setAttribute('github-diff-highlighter-highlighted', true)
                            break
                        catch e
                            # console.log e

    fetchPageHtml: (url, callback) ->
        xhr = new XMLHttpRequest()

        xhr.onerror = =>
            logMessages xhr.status, xhr
            @numPagesToFetchBeforeProcessing--
        xhr.onload = =>
            if xhr.status == 200
                callback null, xhr.responseText
                @numPagesToFetchBeforeProcessing--
                @highlightWhenDataReady()
            else
                xhr.onerror xhr

        xhr.open "GET", url
        xhr.send()

    buildBlobPrefixFromCommitIdentifier: (sha) -> "https://github.com#{currentRepoPath}tree/#{sha}/"
    buildBlobPrefixFromCommitUrl: (commitUrl) -> @buildCommitPathFromSha @endsInShaRegex.exec(commitUrl)[0]

    fetchCurrentHtml: ->
        blobPrefix = @buildBlobPrefixFromCommitIdentifier(@currentCommitIdentifier)
        for filePath in @changedFilePaths
            @currentData[filePath] = file = new File(filePath)
            @fetchPageHtml blobPrefix + filePath, @getStoreHtml(file)

    getStoreHtml: (htmlFile) ->
        (error, html) =>
            files = @getFilesFromHtmlText html
            for file in files
                for line in file.querySelectorAll('.line')
                    lineNumber = parseInt(line.id.substr(2))
                    lineContents = line.innerHTML
                    htmlFile.storeLine line, lineContents, lineNumber

    fetchParentHtml: ->
        for parent in @parentCommitIdentifiers
            blobPrefix = @buildBlobPrefixFromCommitIdentifier(parent)

            @parentData[parent] ||= {}
            for filePath in @changedFilePaths
                @parentData[parent][filePath] = file = new File(filePath)
                @fetchPageHtml blobPrefix + filePath, @getStoreHtml(file)


    getFilesFromHtmlText: (htmlText) ->
        asHtml = document.createElement('html')
        asHtml.innerHTML = htmlText
        asHtml.querySelectorAll('.file')

    getRegularDiffData: ->
        @getDiffData document.querySelectorAll('.file'), @changedFilePaths

    getInlineDiffData: ->
        @getDiffData document.querySelectorAll('.inline-review-comment .file-diff'), @inlineChangedFilePaths

    getDiffData: (changedFileElements, changedFilePaths) ->
        diffData = {}

        for path, i in changedFilePaths
            diffData[path] ||= []
            file = new File(path)
            diffData[path].push file
            lines = changedFileElements[i]?.querySelectorAll('.file-diff-line')
            if lines?
                for line in lines
                    lineNumberElements = line.querySelectorAll('.diff-line-num')
                    [lineNumberPrevious, lineNumberCurrent] = (parseInt(e.getAttribute('data-line-number')) for e in lineNumberElements)
                    lineNumberCurrent ||= parseInt(line.getAttribute('data-line'))
                    lineContainer = line.querySelector('.diff-line-pre')
                    if lineContainer
                        lineContents = lineContainer.innerHTML
                        file.storeDiffLine lineContainer, lineContents, lineNumberPrevious, lineNumberCurrent
        diffData

    fetchAndHighlight: ->
        @fetchCurrentHtml()
        @fetchParentHtml()


## Bootstrap and run

# fix GitHub's css to not force black text on character-by-character diffs
style = document.createElement('style')
style.type = 'text/css'
style.innerHTML = '''
    .highlight span.x {
        color: inherit !important;
    }
'''
document.getElementsByTagName('head')[0].appendChild(style)

diffProcessor = new DiffProcessor()
diffProcessor.fetchAndHighlight()
