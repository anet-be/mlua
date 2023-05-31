function calc_height(oaks)
    for oaktree, _value, index in pairs(oaks) do
        height = oaktree.shadow.__ * math.tan( math.rad(oaktree.angle.__) )
        print(string.format('Oak %s is %.1fm high', index, height))
        oaktree.height.__ = height  -- save back into YDB
    end
end