% runSA - Executes the Simulated Annealing algorithm.
% Returns the final timetable, its cost, and the execution time.
function [finalTimetable, finalCost, elapsedTime] = runSA(app, studentData, examData, venueData, invigilatorData, examTimesData, params)
    % Start the timer
    tic;

    % Has to be executed from the main app
    if nargin < 7
        error('This function should be called from the main application GUI.');
    end

    %% Step 1: Unpack Parameters
    app.StatusLabel.Text = 'Status: Initializing SA parameters...'; drawnow;
    maxIter = params.maxIter;
    initialTemp = params.initialTemp;
    coolingRate = params.coolingRate;
    capacityMultiplier = params.capacityMultiplier;

    numTimeslots = height(examTimesData);
    numExams = height(examData);
    numVenues = height(venueData);
    numInvigilators = height(invigilatorData);

    %% Step 2: Process Input Data
    app.StatusLabel.Text = 'Status: Processing student and invigilator data...'; drawnow;
    students = zeros(height(studentData), numExams);
    for i = 1:height(studentData)
        % Use the safe extraction logic for subjects
        if iscell(studentData.ExamSubjects)
            examSubjectsStr = studentData.ExamSubjects{i};
        else
            examSubjectsStr = studentData.ExamSubjects(i);
        end
        if isnumeric(examSubjectsStr) || islogical(examSubjectsStr)
            examSubjectsStr = string(examSubjectsStr);
        end
        subjectList = strtrim(strsplit(examSubjectsStr, ','));
        for j = 1:length(subjectList)
            examIdx = find(strcmp(examData.ExamName, subjectList{j}));
            if ~isempty(examIdx), students(i, examIdx) = 1; end
        end
    end

    invigilatorAvailability = zeros(numInvigilators, numTimeslots);
    for i = 1:numInvigilators
        try
            availableSlots = str2num(invigilatorData.AvailableTimeslots{i}); 
            if ~isempty(availableSlots)
                invigilatorAvailability(i, availableSlots(availableSlots <= numTimeslots)) = 1;
            end
        catch
            invigilatorAvailability(i, :) = 1; % Assume available if unspecified/error
        end
    end
    
    venueCapacity = round(venueData.Capacity * capacityMultiplier);

    %% Step 3: Main SA Loop
    app.StatusLabel.Text = 'Status: Creating initial SA solution...'; drawnow;
    currentSolution = [randi(numTimeslots, numExams, 1), randi(numVenues, numExams, 1), randi(numInvigilators, numExams, 1)];
    currentCost = calculateCost(currentSolution, students, venueCapacity, invigilatorAvailability);
    bestSolution = currentSolution;
    bestCost = currentCost;
    T = initialTemp;
    
    for iter = 1:maxIter
        if mod(iter, 500) == 0
            app.StatusLabel.Text = sprintf('Status: Running SA Iteration %d/%d... Temp: %.2f', iter, maxIter, T);
            drawnow;
        end
        
        newSolution = perturbSolution(currentSolution, numTimeslots, numVenues, numInvigilators);
        newCost = calculateCost(newSolution, students, venueCapacity, invigilatorAvailability);
        
        if newCost < currentCost || rand() < exp((currentCost - newCost) / T)
            currentSolution = newSolution;
            currentCost = newCost;
            if currentCost < bestCost
                bestSolution = currentSolution;
                bestCost = currentCost;
            end
        end
        
        T = T * coolingRate; % Cool down
    end

    %% Step 4: Finalize and Return Results
    app.StatusLabel.Text = 'Status: Finalizing SA results...'; drawnow;
    
    % Calculate final outputs
    finalCost = bestCost; % The best cost is already tracked
    finalTimetable = formatTimetable(bestSolution, examData, examTimesData, venueData, invigilatorData, students);
    elapsedTime = toc; % Stop the timer
end


%  Helper Functions for SA 

function newSolution = perturbSolution(solution, numTimeslots, numVenues, numInvigilators)
    newSolution = solution;
    exam = randi(size(solution, 1));
    gene = randi(3); % Choose to change timeslot, venue, or invigilator
    if gene == 1, newSolution(exam, 1) = randi(numTimeslots);
    elseif gene == 2, newSolution(exam, 2) = randi(numVenues);
    else, newSolution(exam, 3) = randi(numInvigilators);
    end
end

function cost = calculateCost(timetable, students, venueCapacity, invigilatorAvailability)
    hardPenalty = 0;
    softPenalty = 0;
    timeslots = timetable(:, 1);
    venues = timetable(:, 2);
    invigilators = timetable(:, 3);
    
    for t = 1:max(timeslots)
        examsInSlot = find(timeslots == t);
        if length(examsInSlot) > 1
            hardPenalty = hardPenalty + (sum(sum(students(:, examsInSlot), 2) > 1) * 1000); 
            hardPenalty = hardPenalty + ((length(venues(examsInSlot)) - length(unique(venues(examsInSlot)))) * 800);
            hardPenalty = hardPenalty + ((length(invigilators(examsInSlot)) - length(unique(invigilators(examsInSlot)))) * 700);
        end
    end
    
    for e = 1:size(timetable, 1)
        if sum(students(:, e)) > venueCapacity(venues(e)), hardPenalty = hardPenalty + 500; end
        if ~invigilatorAvailability(invigilators(e), timeslots(e)), hardPenalty = hardPenalty + 600; end
    end
    
    for s = 1:size(students, 1)
        studentExams = find(students(s, :));
        if length(studentExams) > 1
            gaps = diff(sort(timeslots(studentExams)));
            softPenalty = softPenalty + (sum(gaps < 2) * 20);
        end
    end
    cost = hardPenalty + softPenalty;
end


% --- FINAL FIX: formatTimetable function to handle Excel's decimal time format ---
function finalTable = formatTimetable(timetable, examData, examTimes, venueData, invigilatorData, students)
    numExams = height(examData);
    finalTable = table('Size', [numExams, 7], ...
        'VariableTypes', {'string', 'string', 'string', 'double', 'string', 'string', 'string'}, ...
        'VariableNames', {'Day', 'Session', 'Time', 'Students', 'Exam', 'Venue', 'Invigilator'});
    
    for i = 1:numExams
        ts_idx = timetable(i, 1);
        v_idx = timetable(i, 2);
        inv_idx = timetable(i, 3);
        
        if ts_idx >= 1 && ts_idx <= height(examTimes)
            finalTable.Day(i) = safeTableExtract(examTimes, ts_idx, 'Day');
            finalTable.Session(i) = safeTableExtract(examTimes, ts_idx, 'Session');
            
            try
                % Safely get the raw start and end time strings
                startTimeRaw = safeTableExtract(examTimes, ts_idx, 'StartTime');
                endTimeRaw = safeTableExtract(examTimes, ts_idx, 'EndTime');

                % --- Logic to handle both decimal and text time formats ---
                
                % Process Start Time
                [numValStart, isNumericStart] = str2num(startTimeRaw);
                if isNumericStart
                    % It's a number (Excel serial time), so convert it
                    startTimeObj = datetime(numValStart, 'ConvertFrom', 'excel');
                else
                    % It's text, so parse it directly
                    startTimeObj = datetime(startTimeRaw, 'InputFormat', 'HH:mm');
                end

                % Process End Time
                [numValEnd, isNumericEnd] = str2num(endTimeRaw);
                if isNumericEnd
                    endTimeObj = datetime(numValEnd, 'ConvertFrom', 'excel');
                else
                    endTimeObj = datetime(endTimeRaw, 'InputFormat', 'HH:mm');
                end
                
                % Format the final datetime objects into 24-hour strings
                startTimeFmt = datestr(startTimeObj, 'HH:MM');
                endTimeFmt = datestr(endTimeObj, 'HH:MM');
                
                finalTable.Time(i) = sprintf('%s - %s', startTimeFmt, endTimeFmt);

            catch ME
                fprintf('Warning: Could not parse time for timeslot index %d. Error: %s\n', ts_idx, ME.message);
                finalTable.Time(i) = "Invalid Time Format";
            end
        else
            finalTable.Day(i) = "Invalid";
            finalTable.Session(i) = "Invalid";
            finalTable.Time(i) = "Invalid";
        end
        
        finalTable.Students(i) = sum(students(:, i));
        finalTable.Exam(i) = safeTableExtract(examData, i, 'ExamName');
        
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
    
    % Sort sessions chronologically
    sessionOrder = {'Morning', 'Midday', 'Afternoon', 'Evening'};
    sessionNums = zeros(height(finalTable), 1);
    for i = 1:height(finalTable)
        idx = find(strcmp(sessionOrder, finalTable.Session(i)));
        if ~isempty(idx)
            sessionNums(i) = idx;
        else
            sessionNums(i) = 99; % Put unknown sessions at the end
        end
    end
    finalTable.SessionOrder = sessionNums;
    
    finalTable = sortrows(finalTable, {'Day', 'SessionOrder'});
    finalTable.SessionOrder = []; % Remove temporary column
end

% --- safeTableExtract helper function ---
function value = safeTableExtract(tableVar, rowIdx, columnName)
    try
        if ~any(strcmp(tableVar.Properties.VariableNames, columnName))
            value = "Unknown";
            return;
        end
        
        columnData = tableVar.(columnName);
        
        if iscell(columnData)
            value = columnData{rowIdx};
        elseif isdatetime(columnData)
            value = datestr(columnData(rowIdx), 'HH:MM:SS');
        else
            value = columnData(rowIdx);
        end
        
        if ~isstring(value)
            value = string(value);
        end
        
    catch
        value = "Error";
    end
end