function dates = allDatesBetween(startTime,endTime)
%ALLDATESBETWEEN Return all calendar dates between two datetimes

startDate = dateshift(startTime,'start','day');
endDate   = dateshift(endTime,'start','day');
dates     = (startDate:endDate).';
end
