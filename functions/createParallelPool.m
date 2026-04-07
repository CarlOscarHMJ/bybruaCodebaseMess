function createParallelPool(numWorkers)
    pool = gcp('nocreate');
    if ~isempty(pool)
        delete(pool);
    end
    
    availableCores = feature('numcores');
    requestedWorkers = min(numWorkers, availableCores - 1);
    requestedWorkers = max(requestedWorkers, 1);  % Ensure at least 1 worker
    
    parpool('local', requestedWorkers);
end