import reconcileArrays from './reconcileArrays'

isNode = (el) -> el and el.nodeName and el.nodeType

normalizeIncomingArray = (normalized, array) ->
  i = 0
  len = array.length
  while i < len
    item = array[i]
    if item instanceof Node
      normalized.push item
    else if not item? or item is true or item is false
      # matches null, undefined, true or false
      # skip
    else if Array.isArray(item)
      normalizeIncomingArray(normalized, item)
    else if typeof item == 'string'
      normalized.push item
    else
      normalized.push item.toString()
    i++
  normalized

singleExpression = (parent, accessor, options) ->
  current = null
  options.wrapContent accessor, (value) ->
    return if value is current
    t = typeof value
    if t is 'string'
      return current = parent.firstChild.data = value if current
      current = parent.textContent = value
    else if 'number' is t or 'boolean' is t or value instanceof Date or value instanceof RegExp
      value = value.toString()
      return current = parent.firstChild.data = value if current
      current = parent.textContent = value
    else if not value? or t is 'boolean'
      current = parent.textContent = ''
    else if value instanceof Node
      if Array.isArray(current)
        if current.length is 0
          parent.appendChild(value);
        else if current.length is 1
          parent.replaceChild(value, current[0])
        else
          parent.textContent = ''
          parent.appendChild(value)
      else if current is '' or not current?
        parent.appendChild(value)
      else parent.replaceChild(value, parent.firstChild)
      current = value
    else if Array.isArray(value)
      array = normalizeIncomingArray([], value)
      if array.length is 0
        parent.textContent = ''
      else
        if Array.isArray(current)
          if current.length is 0
            parent.appendChild(child) for child in array
          else reconcileArrays(parent, current, array)
        else unless current
          parent.appendChild(child) for child in array
        else reconcileArrays(parent, [parent.firstChild], array)
      current = array
    else
      throw new Error("content must be Node, stringable, or array of same")

multipleExpressions = (parent, accessor, options) ->
  nodes = []
  options.wrapContent accessor, (value) ->
    marker = null
    t = typeof value
    parent = nodes[0]?.parentNode or parent
    if t is 'string' or 'number' is t or 'boolean' is t or value instanceof Date or value instanceof RegExp
      if nodes[0]?.nodeType is 3
        nodes[0].data = value.toString()
        marker = nodes[0]
      else
        value = document.createTextNode(value.toString())
        if nodes[0]
          parent.replaceChild(value, nodes[0])
        else parent.appendChild(value)
        nodes[0] = marker = value
    else if value instanceof Node
      if nodes[0]
        if nodes[0] isnt value
          parent.replaceChild(value, nodes[0])
      else parent.appendChild(value)
      nodes[0] = marker = value
    else if Array.isArray(value)
      array = normalizeIncomingArray([], value)
      if array.length
        unless nodes.length
          for child, i in array
            parent.appendChild(child)
            nodes[i] = child
          marker = nodes[i-1]
        else
          reconcileArrays(parent, nodes, array, true)
          nodes = array
          marker = nodes[nodes.length - 1]

    # handle nulls
    unless marker?
      if nodes[0] is parent.firstChild and nodes.length > 1 and nodes[nodes.length - 1] is parent.lastChild
        parent.textContent = '';
        value = document.createTextNode('');
        parent.appendChild(value)
        marker = nodes[0] = value
      else if nodes[0]?.nodeType is 3
        nodes[0].data = '';
        marker = nodes[0]
      else
        value = document.createTextNode('')
        if nodes[0]
          parent.replaceChild(value, nodes[0])
        else parent.appendChild(value)
        marker = nodes[0] = value

    # trim extras
    while marker isnt (node = nodes[nodes.length - 1])
      parent.removeChild(node)
      nodes.length = nodes.length - 1
    return

export default (options) ->
  # options are wrap, wrapContent
  return {
    assign: (a, b) ->
      a[k] = b[k] for k of b
      return a
    insert: (parent, multiple, accessor) ->
      if multiple
        multipleExpressions(parent, accessor, options)
      else singleExpression(parent, accessor, options)
      return
    wrap: options.wrap
  }