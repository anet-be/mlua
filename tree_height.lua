function calc_height(oaks)
    for oaktree, _value, index in oaks:pairs() do  -- You can also use pairs(oaks) from Lua 5.2
        height = oaktree.shadow.__ * math.tan( math.rad(oaktree.angle.__) )
        print(string.format('Oak %s is %.1fm high', index, height))
        oaktree.height.__ = height  -- save back into YDB
    end
end
