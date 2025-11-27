function chr = CapitalizeText(text)
if isstring(text)
    text = char(text);
    stringflag = 1;
else
    stringflag = 0;
end

chr = [upper(text(1)),text(2:end)];

if stringflag
    chr = string(chr);
end
end