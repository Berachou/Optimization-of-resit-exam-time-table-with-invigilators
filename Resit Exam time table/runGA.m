% runGA - Executes the Genetic Algorithm for timetabling.
% Returns the final timetable, its cost, and the execution time.
function [finalTimetable, finalCost, elapsedTime] = runGA(app, studentData, examData, venueData, invigilatorData, examTimesData, params)
    % Start the timer
    tic;

    % Has to be executed from the main app
    if nargin < 7
        error('This function should be called from the main application GUI.');
    end

    %% Step 1: Unpack Parameters and Data
    app.StatusLabel.Text = 'Status: Initializing GA parameters...'; drawnow;
    populationSize = params.populationSize;
    maxGenerations = params.maxGenerations;
    crossoverRate = params.crossoverRate;
    mutationRate = params.mutationRate;
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
            availableSlots = str2num(invigilatorData.AvailableTimeslots{i}); %#ok<ST2NM>
            if ~isempty(availableSlots)
                invigilatorAvailability(i, availableSlots(availableSlots <= numTimeslots)) = 1;
            end
        catch
            invigilatorAvailability(i, :) = 1; % Assume available if unspecified/error
        end
    end

    venueCapacity = round(venueData.Capacity * capacityMultiplier);

    %% Step 3: Main GA Loop
    app.StatusLabel.Text = 'Status: Initializing GA population...'; drawnow;
    population = initializePopulation(numExams, numTimeslots, numVenues, numInvigilators, populationSize);
    fitness = zeros(1, populationSize);
    for i = 1:populationSize
        fitness(i) = calculateFitness(population{i}, students, venueCapacity, invigilatorAvailability);
    end

    for generation = 1:maxGenerations
        app.StatusLabel.Text = sprintf('Status: Running GA Generation %d/%d...', generation, maxGenerations);
        drawnow;
        
        [~, maxIdx] = max(fitness);
        bestSolution = population{maxIdx};
        
        newPopulation = cell(1, populationSize);
        newPopulation{1} = bestSolution; % Elitism
        
        for i = 2:2:populationSize
            parent1 = population{tournamentSelection(fitness, 3)};
            parent2 = population{tournamentSelection(fitness, 3)};
            [child1, child2] = crossover(parent1, parent2, crossoverRate);
            newPopulation{i} = mutate(child1, mutationRate, numTimeslots, numVenues, numInvigilators);
            if i + 1 <= populationSize
                 newPopulation{i+1} = mutate(child2, mutationRate, numTimeslots, numVenues, numInvigilators);
            end
        end
        population = newPopulation;
        
        for i = 1:populationSize
            fitness(i) = calculateFitness(population{i}, students, venueCapacity, invigilatorAvailability);
        end
    end

    %% Step 4: Finalize and Return Results
    app.StatusLabel.Text = 'Status: Finalizing GA results...'; drawnow;
    [~, bestIdx] = max(fitness);
    finalRawTimetable = population{bestIdx};
    
    % Calculation of final outputs
    finalCost = calculateCost(finalRawTimetable, students, venueCapacity, invigilatorAvailability);
    finalTimetable = formatTimetable(finalRawTimetable, examData, examTimesData, venueData, invigilatorData, students);
    elapsedTime = toc; % Stop the timer
end


% Helper Functions for GA 

function population = initializePopulation(numExams, numTimeslots, numVenues, numInvigilators, populationSize)
    population = cell(1, populationSize);
    for i = 1:populationSize
        timetable = [randi(numTimeslots, numExams, 1), randi(numVenues, numExams, 1), randi(numInvigilators, numExams, 1)];
        population{i} = timetable;
    end
end

function fitness = calculateFitness(timetable, students, venueCapacity, invigilatorAvailability)
    cost = calculateCost(timetable, students, venueCapacity, invigilatorAvailability);
    fitness = 10000 / (1 + cost); % Fitness is inversely proportional to cost
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

function parentIdx = tournamentSelection(fitness, tournamentSize)
    indices = randi(length(fitness), 1, tournamentSize);
    [~, best] = max(fitness(indices));
    parentIdx = indices(best);
end

function [child1, child2] = crossover(parent1, parent2, crossoverRate)
    if rand < crossoverRate
        point = randi(size(parent1, 1) - 1);
        child1 = [parent1(1:point, :); parent2(point+1:end, :)];
        child2 = [parent2(1:point, :); parent1(point+1:end, :)];
    else
        child1 = parent1;
        child2 = parent2;
    end
end

function mutated = mutate(timetable, mutationRate, numTimeslots, numVenues, numInvigilators)
    mutated = timetable;
    for i = 1:size(mutated, 1)
        if rand < mutationRate
            gene = randi(3);
            if gene == 1, mutated(i, 1) = randi(numTimeslots);
            elseif gene == 2, mutated(i, 2) = randi(numVenues);
            else, mutated(i, 3) = randi(numInvigilators);
            end
        end
    end
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