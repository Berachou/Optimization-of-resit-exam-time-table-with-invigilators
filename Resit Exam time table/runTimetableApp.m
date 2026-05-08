% Resit Exam Timetable Optimizer - Simplified Application
function runTimetableApp()
    % Main function that launches the entire application
    clc;
    close all;
    fprintf('Launching Timetable Optimizer Application...\n');

    % Launch application
    mainFig = createMainOptimizerWindow();
    createLoginWindow(mainFig);

    % Main Optimizer GUI
    function fig = createMainOptimizerWindow()
        % Data Storage
        studentData = []; examData = []; venueData = [];
        invigilatorData = []; examTimesData = []; isDataLoaded = false;

        % Algorithm Parameters
        GA_PARAMS = struct('populationSize', 50, 'maxGenerations', 100, ...
                          'crossoverRate', 0.8, 'mutationRate', 0.1);
        SA_PARAMS = struct('maxIter', 20000, 'initialTemp', 100, 'coolingRate', 0.999);

        % Main Figure
        fig = uifigure('Name', 'Resit Exam Timetable Optimizer', ...
                      'Position', [100 100 1200 750], 'Visible', 'off');
        mainGrid = uigridlayout(fig, [1, 2]);
        mainGrid.ColumnWidth = {350, '1x'};

        % Left Panel
        leftPanel = uipanel(mainGrid, 'Title', 'Controls', 'FontSize', 14, ...
                           'BackgroundColor', [0.95 0.95 0.95]);
        controlGrid = uigridlayout(leftPanel, [6, 2]);
        controlGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
        controlGrid.ColumnWidth = {'fit', '1x'};
        controlGrid.Padding = [10 10 10 10];
        controlGrid.RowSpacing = 15;
        controlGrid.ColumnSpacing = 10;

        % Logo
        logoPath = 'C:\Users\razer\Documents\Capstone Project\Image\Cyprus-International-University.png';
        logoImage = uiimage(leftPanel, 'ImageSource', logoPath, ...
                           'Position', [0, 50, 350, 157], 'Visible', 'on');

        % UI Components
        buttonColor = [0.6 0.7 0.9];
        
        importButton = uibutton(controlGrid, 'push', 'Text', ' Import Excel File', ...
                               'FontSize', 14, 'FontWeight', 'bold', ...
                               'ButtonPushedFcn', @importDataCallback, ...
                               'BackgroundColor', buttonColor, 'FontColor', 'k');
        importButton.Layout.Column = [1, 2];

        uilabel(controlGrid, 'Text', 'Algorithm:', 'FontSize', 12, 'HorizontalAlignment', 'right');
        algoDropdown = uidropdown(controlGrid, 'Items', {'Genetic Algorithm', 'Simulated Annealing'}, ...
                                 'FontSize', 12);

        uilabel(controlGrid, 'Text', 'Increase Venue Capacity (25%):', 'FontSize', 12, ...
               'HorizontalAlignment', 'right');
        capacitySwitch = uiswitch(controlGrid, 'Items', {'Off', 'On'}, 'Value', 'Off');

        runButton = uibutton(controlGrid, 'push', 'Text', ' Run Selected Optimization', ...
                            'FontSize', 14, 'FontWeight', 'bold', 'Enable', 'off', ...
                            'ButtonPushedFcn', @runOptimizationCallback, ...
                            'BackgroundColor', buttonColor, 'FontColor', 'k');
        runButton.Layout.Column = [1, 2];

        compareButton = uibutton(controlGrid, 'push', 'Text', ' Run Full Comparison', ...
                                'FontSize', 14, 'FontWeight', 'bold', 'Enable', 'off', ...
                                'ButtonPushedFcn', @runComparisonCallback, ...
                                'BackgroundColor', buttonColor, 'FontColor', 'k');
        compareButton.Layout.Column = [1, 2];

        statusLabel = uilabel(controlGrid, 'Text', 'Status: Application loaded. Please login.', ...
                             'VerticalAlignment', 'top');
        statusLabel.Layout.Row = 6;
        statusLabel.Layout.Column = [1, 2];

        % Right Panel
        rightPanel = uipanel(mainGrid, 'Title', 'Results', 'FontSize', 14, ...
                            'BackgroundColor', [0.95 0.95 0.95]);
        resultsGrid = uigridlayout(rightPanel, [2, 1]);
        resultsGrid.RowHeight = {'1x', 120};

        resultsTable = uitable(resultsGrid, 'FontSize', 11);
        resultsTable.Layout.Row = 1;

        % Comparison Panel
        comparePanel = uipanel(resultsGrid, 'Title', 'Algorithm Comparison', ...
                              'FontSize', 12, 'BackgroundColor', [0.9 0.9 0.9]);
        comparePanel.Layout.Row = 2;

        compareGrid = uigridlayout(comparePanel, [4, 3]);
        compareGrid.ColumnWidth = {'fit', '1x', '1x'};
        compareGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
        compareGrid.ColumnSpacing = 10;
        compareGrid.RowSpacing = 5;

        % Comparison Labels
        uilabel(compareGrid, 'Text', '', 'FontWeight', 'bold');
        uilabel(compareGrid, 'Text', 'Genetic Algorithm', 'FontWeight', 'bold', ...
               'HorizontalAlignment', 'center');
        uilabel(compareGrid, 'Text', 'Simulated Annealing', 'FontWeight', 'bold', ...
               'HorizontalAlignment', 'center');

        uilabel(compareGrid, 'Text', 'Final Cost:', 'HorizontalAlignment', 'right', ...
               'FontWeight', 'bold');
        gaCostLabel = uilabel(compareGrid, 'Text', '0', 'HorizontalAlignment', 'center', ...
                             'FontSize', 14);
        saCostLabel = uilabel(compareGrid, 'Text', '0', 'HorizontalAlignment', 'center', ...
                             'FontSize', 14);

        uilabel(compareGrid, 'Text', 'Time Taken (s):', 'HorizontalAlignment', 'right', ...
               'FontWeight', 'bold');
        gaTimeLabel = uilabel(compareGrid, 'Text', '', 'HorizontalAlignment', 'center', ...
                             'FontSize', 14);
        saTimeLabel = uilabel(compareGrid, 'Text', '', 'HorizontalAlignment', 'center', ...
                             'FontSize', 14);

        exportButton = uibutton(compareGrid, 'push', 'Text', 'Export', 'FontSize', 12, ...
                               'Enable', 'off', 'ButtonPushedFcn', @exportTableCallback, ...
                               'BackgroundColor', buttonColor, 'FontColor', 'k');
        exportButton.Layout.Row = 1;
        exportButton.Layout.Column = 5;

        % Callback Functions
        function importDataCallback(~, ~)
            [file, path] = uigetfile('*.xlsx', 'Select the Timetabling Excel File');
            if isequal(file, 0)
                statusLabel.Text = 'Status: File import canceled.';
                return;
            end
            
            fullFileName = fullfile(path, file);
            statusLabel.Text = 'Status: Importing data... Please wait.';
            drawnow;

            try
                % Load data from Excel sheets
                studentData = readtable(fullFileName, 'Sheet', 'Students');
                venueData = readtable(fullFileName, 'Sheet', 'Venues');
                invigilatorData = readtable(fullFileName, 'Sheet', 'Invigilators');
                examTimesData = readtable(fullFileName, 'Sheet', 'ExamTimes');

                % Extract unique subjects
                allSubjects = extractSubjects(studentData);
                uniqueSubjects = unique(allSubjects);
                examData = table((1:length(uniqueSubjects))', uniqueSubjects', ...
                                'VariableNames', {'ExamID', 'ExamName'});

                % Update UI state
                isDataLoaded = true;
                runButton.Enable = 'on';
                compareButton.Enable = 'on';
                exportButton.Enable = 'off';
                statusLabel.Text = sprintf('Status: Data loaded from %s. Ready to run.', file);
                resultsTable.Data = examData;
                
                % Reset comparison labels
                gaCostLabel.Text = 'N/A';
                saCostLabel.Text = 'N/A';
                gaTimeLabel.Text = '';
                saTimeLabel.Text = '';
                gaCostLabel.FontColor = 'k';
                saCostLabel.FontColor = 'k';
                
            catch ME
                isDataLoaded = false;
                runButton.Enable = 'off';
                compareButton.Enable = 'off';
                statusLabel.Text = 'Status: Error loading file.';
                uialert(fig, ME.message, 'Import Error');
            end
        end

        function runOptimizationCallback(~, ~)
            if ~isDataLoaded, return; end
            disableControls();
            
            app.StatusLabel = statusLabel;
            capacityMultiplier = getCapacityMultiplier();
            GA_PARAMS.capacityMultiplier = capacityMultiplier;
            SA_PARAMS.capacityMultiplier = capacityMultiplier;
            
            try
                if strcmp(algoDropdown.Value, 'Genetic Algorithm')
                    [finalTimetable, finalCost, elapsedTime] = runGA(app, studentData, ...
                        examData, venueData, invigilatorData, examTimesData, GA_PARAMS);
                    gaCostLabel.Text = sprintf('%.0f', finalCost);
                    gaTimeLabel.Text = sprintf('%.2f s', elapsedTime);
                else
                    [finalTimetable, finalCost, elapsedTime] = runSA(app, studentData, ...
                        examData, venueData, invigilatorData, examTimesData, SA_PARAMS);
                    saCostLabel.Text = sprintf('%.0f', finalCost);
                    saTimeLabel.Text = sprintf('%.2f s', elapsedTime);
                end
                
                statusLabel.Text = 'Status: Optimization Complete! Displaying final timetable.';
                resultsTable.Data = finalTimetable;
                exportButton.Enable = 'on';
                
            catch ME
                statusLabel.Text = 'Status: An error occurred during optimization.';
                uialert(fig, ME.message, 'Optimization Error');
            end
            enableControls();
        end

        function runComparisonCallback(~,~)
            if ~isDataLoaded, return; end
            disableControls();
            
            app.StatusLabel = statusLabel;
            capacityMultiplier = getCapacityMultiplier();
            GA_PARAMS.capacityMultiplier = capacityMultiplier;
            SA_PARAMS.capacityMultiplier = capacityMultiplier;

            try
                % Run GA
                [gaTimetable, gaCost, gaTime] = runGA(app, studentData, examData, ...
                    venueData, invigilatorData, examTimesData, GA_PARAMS);
                gaCostLabel.Text = sprintf('%.0f', gaCost);
                gaTimeLabel.Text = sprintf('%.2f s', gaTime);
                
                % Run SA
                [saTimetable, saCost, saTime] = runSA(app, studentData, examData, ...
                    venueData, invigilatorData, examTimesData, SA_PARAMS);
                saCostLabel.Text = sprintf('%.0f', saCost);
                saTimeLabel.Text = sprintf('%.2f s', saTime);

                % Determine best result
                if gaCost <= saCost
                    resultsTable.Data = gaTimetable;
                    gaCostLabel.FontColor = [0 0.6 0]; % Green
                    saCostLabel.FontColor = 'k';
                    statusLabel.Text = 'Status: Comparison complete. GA produced the best result.';
                else
                    resultsTable.Data = saTimetable;
                    saCostLabel.FontColor = [0 0.6 0]; % Green
                    gaCostLabel.FontColor = 'k';
                    statusLabel.Text = 'Status: Comparison complete. SA produced the best result.';
                end
                exportButton.Enable = 'on';
                
            catch ME
                statusLabel.Text = 'Status: An error occurred during comparison.';
                uialert(fig, ME.message, 'Comparison Error');
            end
            enableControls();
        end
        
        function exportTableCallback(~, ~)
            tableData = resultsTable.Data;
            if isempty(tableData)
                statusLabel.Text = 'Status: No data to export.';
                return;
            end
            
            timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
            fileName = sprintf('Generated_Timetable_%s.xlsx', timestamp);
            
            try
                statusLabel.Text = sprintf('Status: Exporting to %s...', fileName);
                drawnow;
                writetable(tableData, fileName);
                statusLabel.Text = sprintf('Status: Timetable successfully exported to %s.', fileName);
            catch ME
                statusLabel.Text = 'Status: Error exporting file.';
                uialert(fig, ME.message, 'Export Error');
            end
        end

        % Helper functions
        function multiplier = getCapacityMultiplier()
            if strcmp(capacitySwitch.Value, 'On')
                multiplier = 1.25;
            else
                multiplier = 1.0;
            end
        end
        
        function disableControls()
            importButton.Enable = 'off';
            runButton.Enable = 'off';
            compareButton.Enable = 'off';
            exportButton.Enable = 'off';
            drawnow;
        end

        function enableControls()
            importButton.Enable = 'on';
            runButton.Enable = 'on';
            compareButton.Enable = 'on';
        end
    end

    % Login Window GUI
    function createLoginWindow(mainAppFigure)
        % Database connection parameters
        dsnName = 'CapstoneLogin';
        dbUser = 'root';
        dbPass = '';
        
        % Create login window
        loginFig = uifigure('Name', 'Administrator Login', ...
                           'Position', [400 400 400 250], 'WindowStyle', 'modal');
        loginFig.CloseRequestFcn = @(~,~) exitApp();
        
        loginGrid = uigridlayout(loginFig, [4, 2]);
        loginGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
        loginGrid.ColumnWidth = {'fit', '1x'};
        loginGrid.Padding = [15 15 15 15];
        loginGrid.RowSpacing = 15;
        loginGrid.ColumnSpacing = 10;
        
        % Login UI components
        uilabel(loginGrid, 'Text', 'Username:', 'HorizontalAlignment', 'right', 'FontSize', 12);
        usernameField = uieditfield(loginGrid, 'Value', 'admin', 'FontSize', 12);
        
        uilabel(loginGrid, 'Text', 'Password:', 'HorizontalAlignment', 'right', 'FontSize', 12);
        passwordField = uieditfield(loginGrid, 'text', 'FontSize', 12);
        
        loginStatusLabel = uilabel(loginGrid, 'Text', 'Please enter your credentials.', ...
                                  'HorizontalAlignment', 'center');
        loginStatusLabel.Layout.Column = [1, 2];
        
        loginButton = uibutton(loginGrid, 'push', 'Text', 'Login', 'FontSize', 14, ...
                              'FontWeight', 'bold', 'ButtonPushedFcn', @loginCallback, ...
                              'BackgroundColor', [0.6 0.7 0.9], 'FontColor', 'k');
        loginButton.Layout.Column = [1, 2];

        function loginCallback(~, ~)
            username = usernameField.Value;
            password = passwordField.Value;

            if isempty(username) || isempty(password)
                loginStatusLabel.Text = 'Username/Password cannot be empty.';
                loginStatusLabel.FontColor = 'r';
                return;
            end

            loginStatusLabel.Text = 'Authenticating...';
            loginStatusLabel.FontColor = 'k';
            drawnow;

            try
                conn = database(dsnName, dbUser, dbPass);
                if ~isempty(conn.Message)
                    error(conn.Message);
                end
                
                % Check developer login
                queryDev = sprintf("SELECT username FROM developer WHERE username = 'developer' AND password_hash = '%s'", password);
                dataDev = fetch(conn, queryDev);
                
                % Check admin login
                query = sprintf("SELECT username FROM administrators WHERE username = '%s' AND password_hash = '%s'", username, password);
                data = fetch(conn, query);
                close(conn);
                
                if height(dataDev) == 1
                    handleSuccessfulLogin('Developer Login Successful!', true);
                elseif height(data) == 1
                    handleSuccessfulLogin('Login Successful!', false);
                else
                    loginStatusLabel.Text = 'Invalid username or password.';
                    loginStatusLabel.FontColor = 'r';
                end
                
            catch ME
                loginStatusLabel.Text = 'Error: Database connection failed.';
                loginStatusLabel.FontColor = 'r';
                uialert(loginFig, ['Connection failed. Details: ' ME.message], 'Database Error');
            end
        end

        function handleSuccessfulLogin(message, isDeveloper)
            loginStatusLabel.Text = message;
            loginStatusLabel.FontColor = [0 0.6 0];
            drawnow;
            pause(1);
            delete(loginFig);
            mainAppFigure.Visible = 'on';

            if isDeveloper
                developerButton = uibutton(mainAppFigure, 'push', 'Text', 'Open MATLAB Editor', ...
                                          'FontSize', 14, 'ButtonPushedFcn', @openEditorCallback, ...
                                          'BackgroundColor', [0.6 0.7 0.9], 'FontColor', 'k');
                developerButton.Position = [50, 400, 150, 30];
            end
        end

        function openEditorCallback(~, ~)
            edit('runTimetableApp.m');
        end

        function exitApp()
            fprintf('Login canceled by user. Exiting application.\n');
            delete(loginFig);
            delete(mainAppFigure);
        end
    end
end

% Helper function to extract subjects from student data
function allSubjects = extractSubjects(studentData)
    allSubjects = {};
    for i = 1:height(studentData)
        % Safe extraction of exam subjects with type checking
        if iscell(studentData.ExamSubjects)
            examSubjectsStr = studentData.ExamSubjects{i};
        else
            examSubjectsStr = studentData.ExamSubjects(i);
        end
        
        % Convert to string if needed
        if isnumeric(examSubjectsStr) || islogical(examSubjectsStr)
            examSubjectsStr = string(examSubjectsStr);
        elseif iscategorical(examSubjectsStr)
            examSubjectsStr = char(examSubjectsStr);
        end
        
        subjects = strtrim(strsplit(examSubjectsStr, ','));
        allSubjects = [allSubjects, subjects];
    end
end

% Safe function to extract table data with type checking
function value = safeTableExtract(tableVar, rowIdx, columnName)
    try
        % Check if the column exists
        if ~any(strcmp(tableVar.Properties.VariableNames, columnName))
            value = "Unknown";
            return;
        end
        
        columnData = tableVar.(columnName);
        
        % Handle different data types
        if iscell(columnData)
            value = columnData{rowIdx};
        elseif isstring(columnData) || ischar(columnData)
            if isstring(columnData)
                value = columnData(rowIdx);
            else
                value = columnData;
            end
        elseif iscategorical(columnData)
            value = char(columnData(rowIdx));
        elseif isnumeric(columnData) || islogical(columnData)
            value = string(columnData(rowIdx));
        else
            value = string(columnData(rowIdx));
        end
        
        % Ensure we return a string
        if ~isstring(value)
            value = string(value);
        end
        
    catch
        value = "Error";
    end
end

% Fixed formatTimetable function with improved validation and type safety
function finalTable = formatTimetable(timetable, examData, examTimes, venueData, invigilatorData, students)
    numExams = height(examData);
    finalTable = table('Size', [numExams, 7], ...
        'VariableTypes', {'string', 'string', 'string', 'double', 'string', 'string', 'string'}, ...
        'VariableNames', {'Day', 'Session', 'Time', 'Students', 'Exam', 'Venue', 'Invigilator'});
    
    % For each exam
    for i = 1:numExams
        ts_idx = timetable(i, 1); % Timeslot ID
        v_idx = timetable(i, 2);  % Venue ID
        inv_idx = timetable(i, 3); % Invigilator ID
        
        % Use actual data from examTimes table with safe extraction
        if ts_idx >= 1 && ts_idx <= height(examTimes)
            finalTable.Day(i) = safeTableExtract(examTimes, ts_idx, 'Day');
            finalTable.Session(i) = safeTableExtract(examTimes, ts_idx, 'Session');
            
            % Use the actual start and end times from the data
            startTime = safeTableExtract(examTimes, ts_idx, 'StartTime');
            endTime = safeTableExtract(examTimes, ts_idx, 'EndTime');
            
            % Ensure 24-hour format (HH:MM)
            finalTable.Time(i) = sprintf('%s - %s', startTime, endTime);
        else
            finalTable.Day(i) = "Invalid";
            finalTable.Session(i) = "Invalid";
            finalTable.Time(i) = "Invalid";
        end
        
        % Other information
        finalTable.Students(i) = sum(students(:, i));
        finalTable.Exam(i) = safeTableExtract(examData, i, 'ExamName');
        
        % Validate venue and invigilator indices with safe extraction
        if v_idx >= 1 && v_idx <= height(venueData)
            finalTable.Venue(i) = safeTableExtract(venueData, v_idx, 'VenueName');
        else
            finalTable.Venue(i) = "Invalid Venue";
        end
        
        if inv_idx >= 1 && inv_idx <= height(invigilatorData)
            finalTable.Invigilator(i) = safeTableExtract(invigilatorData, inv_idx, 'InvigilatorName');
        else
            finalTable.Invigilator(i) = "Invalid Invigilator";
        end
    end
    
    finalTable = sortrows(finalTable, {'Day', 'Session'});
end