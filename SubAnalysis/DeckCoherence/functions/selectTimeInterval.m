function [x,t] = selectTimeInterval(x,t,Period)
assert(length(t) == length(x),'Data and time arrays should be of same length!')
idx = t >= Period(1) & ...
    t <= Period(2);
t = t(idx);
x = x(idx);
end