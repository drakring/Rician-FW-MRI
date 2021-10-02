function results = RicianMagnitudeFitting (echotimes, tesla, Smagnitude, sig, GT, algoparams) %noise SD needed for Rician fit
%function outparams = RicianMagnitudeFitting (echotimes, tesla, Smeasured, sig, GT, algoparams)

% Description: Implements complex fitting with specified bounds
%
% Input:
% echotimes as an m-by-1 vector
% tesla is scalar-valued field strength
% Smeasured is n-by-1 measured signal vector
% sig is estimated noise sigma
% GT is ground truth value to enable ground truth initialisation
% Algoparams contains information on solver, optimoptions and
% initialisation

% Output:
% results structure

% Specify optimisation algorithm options and solver
Ricianfitting.solver=algoparams.solver;
Ricianfitting.options=algoparams.options;

% Define the objective function
Ricianfitting.objective = @(p) -R2RicianObj(p,echotimes,tesla,Smagnitude,sig);


%% Implement complex fitting for both water-dominant and fat-dominant initialisations
% [F W R2* fB0]

%allow fB0 to vary:
% set the parameter lower bound
Ricianfitting.lb = algoparams.lb;

% % set the parameter upper bound
Ricianfitting.ub = algoparams.ub; 

% First assume LOW FF (WATER DOMINANT) TISSUE (Use first echo to provide water guess)
Ricianfitting.x0 = [0.001, algoparams.Sinit, algoparams.vinit, 0]'; 

% run the optimisation
[pmin1, fmin1] = fmincon(Ricianfitting); %fmin is the minimised SSE

% Next assume HIGH FF (FAT DOMINANT) TISSUE (Use first echo to provide water guess)
Ricianfitting.x0 = [algoparams.Sinit, 0.001, algoparams.vinit, 0]'; 

% run the optimisation
[pmin2, fmin2] = fmincon(Ricianfitting); %fmin is the minimised SSE

% Next INITIALISE WITH GROUND TRUTH
Ricianfitting.x0 = GT.p; %Use all four params for complex fitting

% run the optimisation
[pmin3, fmin3] = fmincon(Ricianfitting); %fmin is the minimised SSE

%Add the solutions to outparams
results.pmin1=pmin1;
results.pmin2=pmin2;
results.pmin3=pmin3;

results.fmin1=fmin1;
results.fmin2=fmin2;
results.fmin3=fmin3;

% Choose the estimates from the best residual

if fmin1<=fmin2
    
results.F = pmin1(1);
results.W = pmin1(2);
results.R2 = pmin1(3);

results.fmin = fmin1;
results.chosenmin=1;

% Calculate SSE for complex fitting
[~,results.SSE]=R2Obj(pmin1,echotimes,tesla,Smagnitude,sig);

% Calculate SSE for complex fitting relative to noise-free signal
[~,results.SSEtrue]=R2Obj(pmin1,echotimes,tesla,abs(GT.S),sig);

else
    
results.F = pmin2(1);
results.W = pmin2(2);
results.R2 = pmin2(3);

results.fmin = fmin2;
results.chosenmin=2;

% Calculate SSE for complex fitting
[~,results.SSE]=R2Obj(pmin2,echotimes,tesla,Smagnitude,sig);

% Calculate SSE for complex fitting relative to noise-free signal
[~,results.SSEtrue]=R2Obj(pmin2,echotimes,tesla,abs(GT.S),sig);

end

% Calculate SSE for standard (Gaussian) for ground-truth initialised
% parameters
[~,results.SSEgtinit]=R2Obj(pmin3,echotimes,tesla,Smagnitude,sig); %Relative to measured signal
[~,results.SSEtrue_gtinit]=R2Obj(pmin3,echotimes,tesla,abs(GT.S),sig); %Relative to ground-truth noise-free signal

end



