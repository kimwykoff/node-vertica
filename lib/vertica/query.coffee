EventEmitter    = require('events').EventEmitter
OutgoingMessage = require('./outgoing_message')

class Query extends EventEmitter
  
  constructor: (@connection, sql) ->
    
    @connection._writeMessage(new OutgoingMessage.Query(sql))
    
    @connection.once 'RowDescription',  @onRowDescription.bind(this)
    @connection.on "DataRow",           @onDataRow.bind(this)
    @connection.once 'CommandComplete', @onCommandComplete.bind(this)
    @connection.once 'ErrorResponse',   @onErrorResponse.bind(this)
  
  onRowDescription: (msg) ->
    @fields = []
    for column in msg.columns
      field = new Query.Field(column)
      @emit 'field', field
      @fields.push field
      
    @emit 'fields', @fields
    
  onDataRow: (msg) ->
    row = []
    for value, index in msg.values
      row.push @fields[index].convert(value)
    
    @emit 'row', row
    
  onCommandComplete: (msg) ->
    @connection.removeAllListeners "DataRow"
    @connection.removeAllListeners "ErrorResponse"
    @emit 'end', msg.status
    
  onErrorResponse: (msg) ->
    @connection.removeAllListeners "RowDescription"
    @connection.removeAllListeners "DataRow"
    @connection.removeAllListeners "CommandComplete"
    
    @emit 'error', msg

stringConverters =
  string:  (value) -> value.toString()
  integer: (value) -> parseInt(value)
  float:   (value) -> parseValue(value)
  bool:    (value) -> value.toString() == 't'

fieldConverters =
  0: # text encoded
    25:   stringConverters.string
    1043: stringConverters.string
    20:   stringConverters.integer
    21:   stringConverters.integer
    23:   stringConverters.integer
    26:   stringConverters.integer
    700:  stringConverters.integer
    701:  stringConverters.integer
    1700: stringConverters.float
    16:   stringConverters.bool

class Query.Field
  constructor: (msg) ->
    @name       = msg.name
    @tableId    = msg.tableId
    @fieldIndex = msg.fieldIndex
    @type       = msg.type
    @size       = msg.size
    @modifier   = msg.modifier
    @formatCode = msg.formatCode
    
    @convert = fieldConverters[@formatCode][@type] || ((value) -> value.toString())

module.exports = Query
