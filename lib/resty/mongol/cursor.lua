local t_insert = table.insert
local t_remove = table.remove
local t_concat = table.concat
local strbyte = string.byte
local strformat = string.format


local cursor_methods = { }
local cursor_mt = { __index = cursor_methods }

local function new_cursor(col, query, returnfields, num_each_query)
    return setmetatable ( {
            col = col ;
            query = { ['$query'] = query} ;
            returnfields = returnfields ;

            id = false ;
            results = { } ;

            done = false ;
            i = 0;
            limit_n = 0;
            skip_n = 0;
            num_each = num_each_query or 100,
        } , cursor_mt )
end

cursor_mt.__gc = function( self )
    self.col:kill_cursors({ self.id })
end

cursor_mt.__tostring = function ( ob )
    local t = { }
    for i = 1 , 8 do
        t_insert(t, strformat("%02x", strbyte(ob.id, i, i)))
    end
    return "CursorId(" .. t_concat ( t ) .. ")"
end

function cursor_methods:limit(n)
    assert(n)
    self.limit_n = n
end
function cursor_methods:skip(n)
    assert(n)
    self.skip_n = n
end

--todo
--function cursor_methods:skip(n)

function cursor_methods:sort(fields)
    self.query["$orderby"] = fields
    return self
end

function cursor_methods:next()
    if self.limit_n > 0 and self.i >= self.limit_n then return nil end
    local idx = self.i - math.floor(self.i/self.num_each)*self.num_each
    local v = self.results [ idx  + 1 ]
    if v ~= nil then
        self.i = self.i + 1
        self.results [ idx+1 ] = nil
        return self.i , v
    end

    if self.done then return nil end

    local t
    if not self.id then
    	-- ngx.log(ngx.ERR, "--------- query -------- self.i:", self.i, " num_each:", self.num_each)
        self.id, self.results, t = self.col:query(self.query,
                        self.returnfields, self.skip_n or 0, self.num_each)
        if self.id == "\0\0\0\0\0\0\0\0" then
            self.done = true
        end
    else
    	-- ngx.log(ngx.ERR, "--------- getmore -------- self.num_each:", self.num_each, ", skip:", self.skip_n)
        self.id, self.results, t = self.col:getmore(self.id, self.num_each)

        if self.id == "\0\0\0\0\0\0\0\0" then
            self.done = true
        elseif t.CursorNotFound then
            self.id = false
        end
    end
    return self:next()
end

function cursor_methods:pairs( )
    return self.next, self
end

return new_cursor
