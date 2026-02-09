function testParallelPool()
    % Simple test to verify workers start on Arch/Hyprland
    try
        parpool('local', 2);
        disp('Parallel pool started successfully!');
        delete(gcp('nocreate'));
    catch ME
        fprintf('Error starting pool: %s\n', ME.message);
    end
end