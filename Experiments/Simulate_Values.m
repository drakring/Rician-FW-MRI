
function [FFmaps,errormaps,sdmaps,residuals] = Simulate_Values(SNR,reps)
% function [FFmaps,errormaps,sdmaps,residuals] = Simulate_Values(SNR)

% Description:
% Enables visualisation of FF accuracy and precision over a range of simulated FF and
% R2* values

% Input: 
% SNR, reps

% Output: 
% FF, error, standard deviation and residuals over a range of FF and R2* values

% Author:
% Tim Bray, t.bray@ucl.ac.uk

%% Create grid for different options of each param

%Specify S0
S0=100;

%Create grid
vgrid=repelem(0:0.1:1,51,1); %1ms-1 upper limit chosen to reflect Hernando et al. (went up to 1.2)
Fgrid=S0*repelem([0:0.02:1]',1,11);
Wgrid=S0-Fgrid;

% vgrid=repelem(0:0.2:1,6,1); %1ms-1 upper limit chosen to reflect Hernando et al. (went up to 1.2)
% Fgrid=repelem([0:20:100]',1,6);
% Wgrid=100-Fgrid;

%% Specify parameter values

% Specify echotimes
% MAGO paper at 3T used 12 echoes (TE1 1.1, dTE 1.1)
% MAGO paper at 1.5T used 6 echoes (TE1 1.2, dTE 2)
echotimes=[1.1:1.1:13.2]';
%echotimes=1.2:2:11.2;

%Define fB
fB=0;

%Define field strength
tesla=3;

% Define noise parameters (NB MAGO paper reports typical SNR in vivo of 40
% at 1.5T and 60 at 3T. However, may be lower in the presence of iron or
% marrow. The SNR is a function input. 

noiseSD=S0/SNR; %here assume total signal is 100 for simplicity (since FF maps are used as input)

%Loop through SNR values, finding noise SD for each

%Turn figure show setting on/off
figshow=0;

%% Generate noise (done before looping over voxels)

%Fix the random seed
rng(1);

% Generate the real and imaginary noises
noiseReal_grid = noiseSD*randn(size(Fgrid,1),size(Fgrid,2),numel(echotimes),reps);
noiseImag_grid = noiseSD*randn(size(Fgrid,1),size(Fgrid,2),numel(echotimes),reps);
noise_grid = noiseReal_grid + 1i*noiseImag_grid;

% 
% %Generate simulate 'ROI' for first echo time to get noise estimate for
% %Rician fitting, % with 50 voxels
% NoiseROI= normrnd(0,noiseSD,[200 1]) + i*normrnd(0,noiseSD,[200 1]);
% sigma=std(real(NoiseROI));

%% Initalise GT
GT=struct();

%% Loop through values

for y=1:size(Fgrid,1)
    for x=1:size(Fgrid,2)
        
        W=Wgrid(y,x);
        F=Fgrid(y,x);
        v=vgrid(y,x);

%Simulate noise-free signal
Snoisefree=MultiPeakFatSingleR2(echotimes,3,F,W,v,fB);

% Specify ground truth signal
GT.S = Snoisefree;

%Specify ground truth parameter values
GT.p = [F W v];

%%Loop through reps
parfor r=1:reps

%Get noise from grid
noise=noise_grid(y,x,:,r);

%Reshape
noise=reshape(noise,[],1);

%Add noise
Snoisy=Snoisefree+noise;

%% Implement fitting with noiseless data

% outparams_noiseless = R2fitting(echotimes,3, Smeasured, noiseSD); %Need to take magnitude here; NB fitting will still work without!

%% Implement fitting with noisy data
% This will implement both standard magnitude fitting and with Rician noise
% modelling
outparams = R2fitting(echotimes,3,Snoisy,noiseSD,GT);

%% Plot

if figshow==1

% Plot noisy data
figure('name',strcat('FF= ',num2str(F),'  R2*= ',num2str(v)))
plot(echotimes, abs(Snoisy)); %plot magnitude only 

hold on 

%Plot ground truth data
plot(echotimes, abs(Smeasured), 'Linewidth',3); %plot magnitude only 

%Plot noiseless fits
% plot(echotimes, abs(Fatfunction(echotimes,outparams_noiseless.standard.F,outparams_noiseless.standard.W,outparams_noiseless.standard.R2,0)),'Linewidth',3, 'Linestyle','--')

%Plot for standard fitting
plot(echotimes, abs(Fatfunction(echotimes,tesla,outparams.standard.F,outparams.standard.W,outparams.standard.R2,0)),'Linewidth',3)

%Plot for fitting with Rician noise modelling
%Plot for standard fitting
plot(echotimes, abs(Fatfunction(echotimes,tesla,outparams.Rician.F,outparams.Rician.W,outparams.Rician.R2,0)),'Linewidth',3)

%Plot for complex fitting
plot(echotimes, abs(Fatfunction(echotimes,tesla,outparams.complex.F,outparams.complex.W,outparams.complex.R2,0)),'Linewidth',3)

%% Add legend
legend('Noisy data', 'Ground truth', 'Standard magnitude fitting', 'Rician magnitude fitting', 'Complex fitting')
ax=gca;
ax.FontSize=14;
xlabel('Echo Time (ms)');
ylabel('Signal');

%% Print data
disp(outparams.standard)
disp(outparams.Rician)
disp(outparams.complex)

else ;
end


%% Add parameter estimates to grid

%For two-point initialisation

%For FF
FF_standard(y,x,r)=outparams.standard.F/(outparams.standard.W+outparams.standard.F);
FF_Rician(y,x,r)=outparams.Rician.F/(outparams.Rician.W+outparams.Rician.F);
FF_complex(y,x,r)=outparams.complex.F/(outparams.complex.W+outparams.complex.F);

%For R2*
vhat_standard(y,x,r)=outparams.standard.R2;
vhat_Rician(y,x,r)=outparams.Rician.R2;
vhat_complex(y,x,r)=outparams.complex.R2;


%For ground-truth initialised values

%For FF
FF_standard_gtinitialised(y,x,r)=outparams.standard.pmin3(1)/(outparams.standard.pmin3(2)+outparams.standard.pmin3(1));
FF_Rician_gtinitialised(y,x,r)=outparams.Rician.pmin3(1)/(outparams.Rician.pmin3(2)+outparams.Rician.pmin3(1));
FF_complex_gtinitialised(y,x,r)=outparams.complex.pmin3(1)/(outparams.complex.pmin3(2)+outparams.complex.pmin3(1));

%For R2*
vhat_standard_gtinitialised(y,x,r)=outparams.standard.pmin3(3);
vhat_Rician_gtinitialised(y,x,r)=outparams.Rician.pmin3(3);
vhat_complex_gtinitialised(y,x,r)=outparams.complex.pmin3(3);

%% Add fitting residuals to grid
fmin1standard(y,x,r)=outparams.standard.fmin1;
fmin2standard(y,x,r)=outparams.standard.fmin2;
fmin3standard(y,x,r)=outparams.standard.fmin3;

fmin1Rician(y,x,r)=outparams.Rician.fmin1;
fmin2Rician(y,x,r)=outparams.Rician.fmin2;
fmin3Rician(y,x,r)=outparams.Rician.fmin3;

fmin1complex(y,x,r)=outparams.complex.fmin1;
fmin2complex(y,x,r)=outparams.complex.fmin2;
fmin3complex(y,x,r)=outparams.complex.fmin3;

%SSE 
SSEstandard(y,x,r)=outparams.standard.SSE; %NB SSE matches the lower of the two residuals above (i.e. the chosen likelihood maximum / error minimum)
SSERician(y,x,r)=outparams.Rician.SSE;
SSEcomplex(y,x,r)=outparams.complex.SSE;

%SSE true (relative to ground truth noise-free signal)
SSEtrue_standard(y,x,r)=outparams.standard.SSEtrue;
SSEtrue_Rician(y,x,r)=outparams.Rician.SSEtrue;
SSEtrue_complex(y,x,r)=outparams.complex.SSEtrue;

%SSE versus true noise 
SSEvsTrueNoise_standard(y,x,r)=outparams.standard.SSE / (noise'*noise); %Use conjugate transpose for calculation of 'noise SSE' (denominator)
SSEvsTrueNoise_Rician(y,x,r)=outparams.Rician.SSE / (noise'*noise);
SSEvsTrueNoise_complex(y,x,r)=outparams.complex.SSE / (noise'*noise);

%SSE with ground-truth initialisation 
SSEgtinit_standard(y,x,r)=outparams.standard.SSEgtinit;
SSEgtinit_Rician(y,x,r)=outparams.Rician.SSEgtinit;
SSEgtinit_complex(y,x,r)=outparams.complex.SSEgtinit;

%SSE true with ground-truth initialisation 
SSEgtinit_true_standard(y,x,r)=outparams.standard.SSEtrue_gtinit;
SSEgtinit_true_Rician(y,x,r)=outparams.Rician.SSEtrue_gtinit;
SSEgtinit_true_complex(y,x,r)=outparams.complex.SSEtrue_gtinit;

%SSE with ground-truth initialisation vs true noise
%SSE versus true noise 
SSEgtinitvsTrueNoise_standard(y,x,r)=outparams.standard.SSEgtinit / (noise'*noise); %Use conjugate transpose for calculation of 'noise SSE' (denominator)
SSEgtinitvsTrueNoise_Rician(y,x,r)=outparams.Rician.SSEgtinit / (noise'*noise);
SSEgtinitvsTrueNoise_complex(y,x,r)=outparams.complex.SSEgtinit / (noise'*noise);

    end
end
end

close all 

%% Average grids over repetitions

%For two point initialisation
FF_standard_mean=100*mean(FF_standard,3); %Convert to percentage
FF_Rician_mean=100*mean(FF_Rician,3);
FF_complex_mean=100*mean(FF_complex,3);

vhat_standard_mean=mean(vhat_standard,3);
vhat_Rician_mean=mean(vhat_Rician,3);
vhat_complex_mean=mean(vhat_complex,3);

residuals.standard.fmin1=mean(fmin1standard,3);
residuals.standard.fmin2=mean(fmin2standard,3);
residuals.standard.SSE=mean(SSEstandard,3);
residuals.standard.SSEtrue=mean(SSEtrue_standard,3);
residuals.standard.SSEvstruenoise=mean(SSEvsTrueNoise_standard,3);
residuals.standard.SSEgtinit=mean(SSEgtinit_standard,3);
residuals.standard.SSEgtinit_true=mean(SSEgtinit_true_standard,3);
residuals.standard.SSEgtinitvstruenoise=mean(SSEgtinitvsTrueNoise_standard,3);


residuals.Rician.fmin1=mean(fmin1Rician,3);
residuals.Rician.fmin2=mean(fmin2Rician,3);
residuals.Rician.SSE=mean(SSERician,3);
residuals.Rician.SSEtrue=mean(SSEtrue_Rician,3);
residuals.Rician.SSEvstruenoise=mean(SSEvsTrueNoise_Rician,3);
residuals.Rician.SSEgtinit=mean(SSEgtinit_Rician,3);
residuals.Rician.SSEgtinit_true=mean(SSEgtinit_true_Rician,3);
residuals.Rician.SSEgtinitvstruenoise=mean(SSEgtinitvsTrueNoise_Rician,3);

residuals.complex.fmin1=mean(fmin1complex,3);
residuals.complex.fmin2=mean(fmin2complex,3);
residuals.complex.SSE=mean(SSEcomplex,3);
residuals.complex.SSEtrue=mean(SSEtrue_complex,3);
residuals.complex.SSEvstruenoise=mean(SSEvsTrueNoise_complex,3);
residuals.complex.SSEgtinit=mean(SSEgtinit_complex,3);
residuals.complex.SSEgtinit_true=mean(SSEgtinit_true_complex,3);
residuals.complex.SSEgtinitvstruenoise=mean(SSEgtinitvsTrueNoise_complex,3);

%For ground truth initialisation

FF_standard_mean_gtinitialised=100*mean(FF_standard_gtinitialised,3); %Convert to percentage
FF_Rician_mean_gtinitialised=100*mean(FF_Rician_gtinitialised,3);
FF_complex_mean_gtinitialised=100*mean(FF_complex_gtinitialised,3);

vhat_standard_mean_gtinitialised=mean(vhat_standard_gtinitialised,3);
vhat_Rician_mean_gtinitialised=mean(vhat_Rician_gtinitialised,3);
vhat_complex_mean_gtinitialised=mean(vhat_complex_gtinitialised,3);

%% Get SD of grids over repetitions

%For two-point initialisation
vhat_standard_sd=std(vhat_standard,0,3);
vhat_Rician_sd=std(vhat_Rician,0,3);
vhat_complex_sd=std(vhat_complex,0,3);

FF_standard_sd=100*std(FF_standard,0,3); %Convert to percentage
FF_Rician_sd=100*std(FF_Rician,0,3);
FF_complex_sd=100*std(FF_complex,0,3);

%For ground-truth initialisation
FF_standard_sd_gtinitialised=100*std(FF_standard_gtinitialised,0,3); %Convert to percentage
FF_Rician_sd_gtinitialised=100*std(FF_Rician_gtinitialised,0,3);
FF_complex_sd_gtinitialised=100*std(FF_complex_gtinitialised,0,3);


%% Create error grids

%For two-point initialisation
FFerror_standard=FF_standard_mean-Fgrid;
FFerror_Rician=FF_Rician_mean-Fgrid;
FFerror_complex=FF_complex_mean-Fgrid;

R2error_standard=vhat_standard_mean-vgrid;
R2error_Rician=vhat_Rician_mean-vgrid;
R2error_complex=vhat_complex_mean-vgrid;

%For ground-truth initialisation
FFerror_standard_gtinitialised=FF_standard_mean_gtinitialised-Fgrid;
FFerror_Rician_gtinitialised=FF_Rician_mean_gtinitialised-Fgrid;
FFerror_complex_gtinitialised=FF_complex_mean_gtinitialised-Fgrid;

R2error_standard_gtinitialised=vhat_standard_mean_gtinitialised-vgrid;
R2error_Rician_gtinitialised=vhat_Rician_mean_gtinitialised-vgrid;
R2error_complex_gtinitialised=vhat_complex_mean_gtinitialised-vgrid;

%% Add to structure

%For two-point initialised
FFmaps.standard=FF_standard_mean; %Convert to percentage
FFmaps.Rician=FF_Rician_mean;
FFmaps.complex=FF_complex_mean;

errormaps.R2standard=R2error_standard;
errormaps.R2rician=R2error_Rician;
errormaps.R2complex=R2error_complex;

errormaps.FFstandard=FFerror_standard;
errormaps.FFrician=FFerror_Rician;
errormaps.FFcomplex=FFerror_complex;

sdmaps.R2standard=vhat_standard_sd;
sdmaps.R2rician=vhat_Rician_sd;
sdmaps.R2complex=vhat_complex_sd;

sdmaps.FFstandard=FF_standard_sd;
sdmaps.FFrician=FF_Rician_sd;
sdmaps.FFcomplex=FF_complex_sd;

%For ground-truth initialisation
errormaps.FFstandard_gtinitialised=FFerror_standard_gtinitialised;
errormaps.FFrician_gtinitialised=FFerror_Rician_gtinitialised;
errormaps.FFcomplex_gtinitialised=FFerror_complex_gtinitialised;

errormaps.R2standard_gtinitialised=R2error_standard_gtinitialised;
errormaps.R2rician_gtinitialised=R2error_Rician_gtinitialised;
errormaps.R2complex_gtinitialised=R2error_complex_gtinitialised;

sdmaps.FFstandard_gtinitialised=FF_standard_sd_gtinitialised;
sdmaps.FFrician_gtinitialised=FF_Rician_sd_gtinitialised;
sdmaps.FFcomplex_gtinitialised=FF_complex_sd_gtinitialised;

%% Find mean parameter error values
meanerror.standard=mean(abs(errormaps.FFstandard),'all');
meanerror.Rician=mean(abs(errormaps.FFrician),'all');
meanerror.complex=mean(abs(errormaps.FFcomplex),'all');

%% Create figures
Createfig(FFmaps,errormaps,sdmaps,residuals)
