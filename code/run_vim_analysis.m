function results = run_vim_analysis
%% function results = run_vim_analysis
% Run the analysis for "Ventralis intermedius nucleus anatomical variability
% assessment by MRI structural connectivity". Return structured array with
% results and all figures.
%--------------------------------------------------------------------------
% Version History:
% 1.5 May 2021 - Removed two subjects with warping errors, found after
% following up with comments from reviewers
% 1.4 February 2021 - Add in test-retest data and volume data following
% comments from reviewers
% 1.3, June 2020 - Add raincloud plots, add surface plot from eig(cov), add
% Pitman-Morgan test, corrected tables, ttest on coordinate positions
% (absolute values for ml),z-test to compare surgical coordinates
% 1.2, June 2020 - x,y,z variable labels replaced with ap,ml,si to avoid
% confusion between spaces/conventions. All coordinates/mapping
% internally consistent. Identical results.
% 1.1, May 2020 - Rendering command added. All measurements voxel to world. All
% coordinates are internally consistent with MATLAB centroid command where
% x = AP, y = ML and z = SI (which requires some re-mapping when working
% out world coordinates, but all are re-ordered to the convention given
% unless otherwise specified).
%--------------------------------------------------------------------------
% F.Ferreira
% Akram H
% Ashburner J
% Hui Zhang
% C.Lambert
%--------------------------------------------------------------------------

%% Issue a few checks:
[logfile,proc]=vim_version_check;

if ~proc
    return
end

options     = vim_analysis_defaults;
Affine      = options.affine;

if isempty(options.pth)
    options.pth     = spm_select(1,'dir','Select folder vim_analysis');
end

UD          = char(strcat('Working path:',options.pth));disp(UD);
logfile     = char(logfile,UD);

%% Load data:
pth         = fullfile(options.pth,'data','derivatives');
l_surf      = fullfile(pth,'surfaces','surf_thalamus_left.gii');
r_surf      = fullfile(pth,'surfaces','surf_thalamus_right.gii');
output      = fullfile(options.pth,'results');

% make sure results folder exists
if ~exist(output, 'dir')
    mkdir(output)
end

results.centroid_tractography.left_vim.data     = spm_load(fullfile(pth,'centroid_tractography','vim_tract-centroids_left.tsv'));

%Two bad warps spotted by reviewer 2
results.centroid_tractography.left_vim.data.ap(options.remove==1)=[];
results.centroid_tractography.left_vim.data.ml(options.remove==1)=[];
results.centroid_tractography.left_vim.data.si(options.remove==1)=[];

results.centroid_tractography.right_vim.data    = spm_load(fullfile(pth,'centroid_tractography','vim_tract-centroids_right.tsv'));
results.centroid_tractography.right_vim.data.ap(options.remove==1)=[];
results.centroid_tractography.right_vim.data.ml(options.remove==1)=[];
results.centroid_tractography.right_vim.data.si(options.remove==1)=[];

results.centroid_tractography.left_vim.data.vol = spm_load(fullfile(pth,'centroid_volume','vim_volume-centroids_left.tsv'));results.centroid_tractography.left_vim.data.vol(options.remove==1)=[];
results.centroid_tractography.right_vim.data.vol= spm_load(fullfile(pth,'centroid_volume','vim_volume-centroids_right.tsv'));results.centroid_tractography.right_vim.data.vol(options.remove==1)=[];
results.centroid_surgical.left_vim.data         = spm_load(fullfile(pth,'centroid_coordinate','vim_coord-centroids_left.tsv'));
results.centroid_surgical.right_vim.data        = spm_load(fullfile(pth,'centroid_coordinate','vim_coord-centroids_right.tsv'));
results.confound.volume.tiv.data                = spm_load(fullfile(pth,'confounds','confound_volume_tiv.tsv'));results.confound.volume.tiv.data(options.remove==1)=[];
results.confound.volume.left_m1.data            = spm_load(fullfile(pth,'confounds','confound_volume_m1_left.tsv'));results.confound.volume.left_m1.data(options.remove==1)=[];
results.confound.volume.right_m1.data           = spm_load(fullfile(pth,'confounds','confound_volume_m1_right.tsv'));results.confound.volume.right_m1.data(options.remove==1)=[];
results.confound.volume.left_dentate.data       = spm_load(fullfile(pth,'confounds','confound_volume_dentate_left.tsv'));results.confound.volume.left_dentate.data(options.remove==1)=[];
results.confound.volume.right_dentate.data      = spm_load(fullfile(pth,'confounds','confound_volume_dentate_right.tsv'));results.confound.volume.right_dentate.data(options.remove==1)=[];
results.confound.movement.eddyrms_first.data    = spm_load(fullfile(pth,'confounds','confound_movement_eddyrms_first.tsv'));results.confound.movement.eddyrms_first.data(options.remove==1)=[]; 
results.confound.movement.eddyrms_last.data     = spm_load(fullfile(pth,'confounds','confound_movement_eddyrms_last.tsv'));results.confound.movement.eddyrms_last.data(options.remove==1)=[]; 

%% Test-retest HCP data
results.testretest.session1.left_vim.data       = spm_load(fullfile(pth,'centroid_test-retest','vim_tract_testretest_scan1_left.tsv'));
results.testretest.session2.left_vim.data       = spm_load(fullfile(pth,'centroid_test-retest','vim_tract_testretest_scan2_left.tsv'));
results.testretest.session1.right_vim.data      = spm_load(fullfile(pth,'centroid_test-retest','vim_tract_testretest_scan1_right.tsv'));
results.testretest.session2.right_vim.data      = spm_load(fullfile(pth,'centroid_test-retest','vim_tract_testretest_scan2_right.tsv'));

%% Test-retest HCP volume data
results.testretest.session1.left_vim.data.vol   = spm_load(fullfile(pth,'centroid_test-retest','vim_volume_testretest_scan1_left.tsv'));
results.testretest.session2.left_vim.data.vol   = spm_load(fullfile(pth,'centroid_test-retest','vim_volume_testretest_scan2_left.tsv'));
results.testretest.session1.right_vim.data.vol  = spm_load(fullfile(pth,'centroid_test-retest','vim_volume_testretest_scan1_right.tsv'));
results.testretest.session2.right_vim.data.vol  = spm_load(fullfile(pth,'centroid_test-retest','vim_volume_testretest_scan2_right.tsv'));

%% Define some function handles:
split_xyz       = @(p)struct('ap',p(1),'ml',p(2),'si',p(3));
mean_std        = @(data)struct('data',data,'mean',mean(data),'std',std(data));

%% Summarise measures:
UD=char(strcat('Running analysis'));disp(UD);logfile=char(logfile,UD);

for hemisphere=1:2
    % Do left and then right
    if hemisphere==1
        vim      = results.centroid_tractography.left_vim;
        surgical = results.centroid_surgical.left_vim.data;
        ses1     = results.testretest.session1.left_vim;
        ses2     = results.testretest.session2.left_vim;
    else
        vim      = results.centroid_tractography.right_vim;
        surgical = results.centroid_surgical.right_vim.data;
        ses1     = results.testretest.session1.right_vim;
        ses2     = results.testretest.session2.right_vim;
    end
    
    %% VIM: Summary
    tmp                 = vim.data;
    X                   = (Affine(1:3,1:3)*[tmp.ml tmp.ap tmp.si]')+Affine(1:3,4); %Voxel to world, results in mm
    X                   = [X(2,:);X(1,:);X(3,:)]; %Keep it all internally consisent with matlab centroid coords.
    
    N                   = size(X,2);                          % Number of samples
    mu                  = mean(X,2);                          % Mean centroid position
    R                   = bsxfun(@minus,X,mu);                % Displacements relative to mean centroid position
    vim.mean            = split_xyz(mu);                      % Mean centroid position (reformatted)
    vim.std             = split_xyz(sqrt(sum(R.^2,2)/(N-1))); % Standard deviations of displacements along AP, ML, SI
    vim.max             = split_xyz(max(abs(R),[],2));        % Maximum absolute displacements along AP, ML, SI
    
    % Euclidean distance from average
    vim.ed.data         = sqrt(sum(R.^2,1))';             % Absolute displacements
    vim.ed.mean         = mean(vim.ed.data);              % Mean absolute displacement
    vim.ed.mx           = max(vim.ed.data);               % Maximum absolute displacement
    vim.ed.std          = std(vim.ed.data);               % Standard deviation of absolute displacements
    vim.Sig             = R*R'/(N-1);                     % Covariance matrix (for visualisation)
    vim.rms             = sqrt(sum(sum(R.^2,1),2)/(N-1)); % RMS displacement: sqrt(trace(Sig))
    
    % Volume
    vim.volume.mean     = mean(tmp.vol);            
    vim.volume.median   = median(tmp.vol);             
    vim.volume.std      = std(tmp.vol);              
    
    % Results tract vs surgical
    tmp                             = cell2mat(struct2cell(surgical));
    mu                              = Affine(1:3,1:3)*([tmp(2) tmp(1) tmp(3)]')+Affine(1:3,4);
    smu{hemisphere}                 = [mu(2);mu(1);mu(3)];
    R                               = bsxfun(@minus,X,smu{hemisphere});
    vim.surgicaldifference.std      = split_xyz(sqrt(sum(R.^2,2)/(N-1)));
    vim.surgicaldifference.max      = split_xyz(max(abs(R),[],2));
    vim.surgicaldifference.ed.data  = sqrt(sum(R.^2,1))';
    vim.surgicaldifference.ed.mean  = mean(vim.surgicaldifference.ed.data);
    vim.surgicaldifference.ed.std   = std(vim.surgicaldifference.ed.data);
    vim.surgicaldifference.ed.mx    = max(vim.surgicaldifference.ed.data);
    vim.surgicaldifference.rms      = sqrt(sum(sum(R.^2,1),2)/(N-1));
    
    % VIM: Session1
    tmp                     = ses1.data;
    X1                      = (Affine(1:3,1:3)*[tmp.ml tmp.ap tmp.si]')+Affine(1:3,4); %Voxel to world, results in mm
    X1                      = [X1(2,:);X1(1,:);X1(3,:)]; %Keep it all internally consisent with matlab centroid coords.
    
    N                       = size(X1,2);                          % Number of samples
    mu                      = mean(X1,2);                          % Mean centroid position
    R                       = bsxfun(@minus,X1,mu);                % Displacements relative to mean centroid position
    ses1.mean           = split_xyz(mu);                      % Mean centroid position (reformatted)
    ses1.std            = split_xyz(sqrt(sum(R.^2,2)/(N-1))); % Standard deviations of displacements along AP, ML, SI
    ses1.max            = split_xyz(max(abs(R),[],2));        % Maximum absolute displacements along AP, ML, SI
    
%     ses1.volume.mean    = mean(tmp.vol);            
%     ses1.volume.median  = median(tmp.vol);             
%     ses1.volume.std     = std(tmp.vol);
    
    tmp                     = ses2.data;
    X2                      = (Affine(1:3,1:3)*[tmp.ml tmp.ap tmp.si]')+Affine(1:3,4); %Voxel to world, results in mm
    X2                      = [X2(2,:);X2(1,:);X2(3,:)]; %Keep it all internally consisent with matlab centroid coords.
    
    N                       = size(X2,2);                          % Number of samples
    mu                      = mean(X2,2);                          % Mean centroid position
    R                       = bsxfun(@minus,X2,mu);                % Displacements relative to mean centroid position
    ses2.mean           = split_xyz(mu);                      % Mean centroid position (reformatted)
    ses2.std            = split_xyz(sqrt(sum(R.^2,2)/(N-1))); % Standard deviations of displacements along AP, ML, SI
    ses2.max            = split_xyz(max(abs(R),[],2));        % Maximum absolute displacements along AP, ML, SI

%     ses2.volume.mean    = mean(tmp.vol);            
%     ses2.volume.median  = median(tmp.vol);             
%     ses2.volume.std     = std(tmp.vol);
    
    if hemisphere==1
        results.centroid_tractography.left_vim  = vim;
        results.testretest.session1.left_vim    = ses1;
        results.testretest.session2.left_vim    = ses2;
        XLrt{1}=X1'; XLrt{2}=X2'; XL = X';%Store for stats, N-by-3 arrays
    else
        results.centroid_tractography.right_vim = vim;
        results.testretest.session1.right_vim   = ses1;
        results.testretest.session2.right_vim   = ses2;
        XRrt{1}=X1'; XRrt{2}=X2'; XR = X';
    end
end

%% Confounds:
for nam=fieldnames(results.confound.volume)'
    results.confound.volume.(nam{1})    = mean_std(results.confound.volume.(nam{1}).data);
end
for nam=fieldnames(results.confound.movement)'
    results.confound.movement.(nam{1})  = mean_std(results.confound.movement.(nam{1}).data);
end

%% STATS 1: Left vs. Right position
[~,results.statistics.leftright.pos.ap] = ttest(XL(:,1),XR(:,1));
[~,results.statistics.leftright.pos.ml] = ttest(abs(XL(:,2)),abs(XR(:,2)));
[~,results.statistics.leftright.pos.si] = ttest(XL(:,3),XR(:,3));

%% STATS 2: Left vs. Right variance
results.statistics.leftright.var.ap     = pitmanmorgantest(XL(:,1),XR(:,1));
results.statistics.leftright.var.ml     = pitmanmorgantest(XL(:,2),XR(:,2));
results.statistics.leftright.var.si     = pitmanmorgantest(XL(:,3),XR(:,3));

%% STATS 2: Left vs. Right volume (non-parametric
[results.statistics.leftright.vol,~]    = signrank(results.centroid_tractography.left_vim.data.vol,results.centroid_tractography.right_vim.data.vol);  

%% STATS 4: Versus Atlas position
[~,results.statistics.atlas.left.ap]    = ttest(XL(:,1),smu{1}(1));
[~,results.statistics.atlas.left.ml]    = ttest(XL(:,2),smu{1}(2));
[~,results.statistics.atlas.left.si]    = ttest(XL(:,3),smu{1}(3));
[~,results.statistics.atlas.right.ap]   = ttest(XR(:,1),smu{2}(1));
[~,results.statistics.atlas.right.ml]   = ttest(XR(:,2),smu{2}(2));
[~,results.statistics.atlas.right.si]   = ttest(XR(:,3),smu{2}(3));

%% STATS 5: Confound analysis
in  = results.confound;clear out

if isfield(results,'statistics') && isfield(results.statistics,'confound'), out = results.statistics.confound; end

% F statistic result fields
out.left.volume.tiv             = do_fstat(in.volume.tiv.data,XL);
out.right.volume.tiv            = do_fstat(in.volume.tiv.data,XR);
out.left.volume.m1              = do_fstat(in.volume.left_m1.data,XL);
out.right.volume.m1             = do_fstat(in.volume.right_m1.data,XR);
out.left.volume.dentate         = do_fstat(in.volume.left_dentate.data,XL);
out.right.volume.dentate        = do_fstat(in.volume.right_dentate.data,XR);
out.left.movement.eddy_first    = do_fstat(in.movement.eddyrms_first.data,XL);
out.right.movement.eddy_first   = do_fstat(in.movement.eddyrms_first.data,XR);
out.left.movement.eddy_last     = do_fstat(in.movement.eddyrms_last.data,XL);
out.right.movement.eddy_last    = do_fstat(in.movement.eddyrms_last.data,XR);

results.statistics.confound     = out;

%% STATS 5: Test-retest
%% VIM: Summary
 R1 = sqrt(sum((XLrt{1}'-XLrt{2}').^2,1))';
 R2 = sqrt(sum((XLrt{1}'-mean(XLrt{1}',2)).^2,1))';
 %R3 = sqrt(sum((XLrt{2}'-mean(XLrt{2}',2)).^2,1))';
 N=numel(R1);
 
[~,results.statistics.testretest.left.centroid] = ttest(R1,R2);
[~,results.statistics.testretest.left.ap] = ttest(abs(XLrt{1}(:,1)-XLrt{2}(:,1)),abs(XLrt{1}(:,1)-mean(XLrt{1}(:,1))));
[~,results.statistics.testretest.left.ml] = ttest(abs(XLrt{1}(:,2)-XLrt{2}(:,2)),abs(XLrt{1}(:,2)-mean(XLrt{1}(:,2))));
[~,results.statistics.testretest.left.si] = ttest(abs(XLrt{1}(:,3)-XLrt{2}(:,3)),abs(XLrt{1}(:,3)-mean(XLrt{1}(:,3))));
%[~,results.statistics.testretest.scan2.left] = ttest(R1,R3);

results.testretest.overall.left.rms.within=sqrt(sum(sum(R1.^2,1),2)/(N-1));
results.testretest.overall.left.rms.between=sqrt(sum(sum(R2.^2,1),2)/(N-1));
%results.testretest.overall.left.rms.scan2mean=sqrt(sum(sum(R3.^2,1),2)/(N-1));

 R1 = sqrt(sum((XRrt{1}'-XRrt{2}').^2,1))';
 R2 = sqrt(sum((XRrt{1}'-mean(XRrt{1}',2)).^2,1))';
 %R3 = sqrt(sum((XRrt{2}'-mean(XRrt{2}',2)).^2,1))';
 N=numel(R1);

[~,results.statistics.testretest.right.centroid] = ttest(R1,R2);
[~,results.statistics.testretest.right.ap] = ttest(abs(XRrt{1}(:,1)-XRrt{2}(:,1)),abs(XRrt{1}(:,1)-mean(XRrt{1}(:,1))));
[~,results.statistics.testretest.right.ml] = ttest(abs(XRrt{1}(:,2)-XRrt{2}(:,2)),abs(XRrt{1}(:,2)-mean(XRrt{1}(:,2))));
[~,results.statistics.testretest.right.si] = ttest(abs(XRrt{1}(:,3)-XRrt{2}(:,3)),abs(XRrt{1}(:,3)-mean(XRrt{1}(:,3))));
%[~,results.statistics.testretest.scan2.right] = ttest(R1,R3);

results.testretest.overall.right.rms.within=sqrt(sum(sum(R1.^2,1),2)/(N-1));
results.testretest.overall.right.rms.between=sqrt(sum(sum(R2.^2,1),2)/(N-1));
%results.testretest.overall.right.rms.scan2mean=sqrt(sum(sum(R3.^2,1),2)/(N-1));

%% Print out and store some tables
% Summary of VIM positions
lv = results.centroid_tractography.left_vim;
rv = results.centroid_tractography.right_vim;
x  = [lv.mean.ap; rv.mean.ap];
y  = [lv.mean.ml; rv.mean.ml];
z  = [lv.mean.si; rv.mean.si];
xs = [lv.std.ap;  rv.std.ap ];
ys = [lv.std.ml;  rv.std.ml ];
zs = [lv.std.si;  rv.std.si ];

dat         = [x xs y ys z zs];
colnames    = {'Mean AP','Std AP (mm)','Mean ML','Std ML (mm)','Mean SI','Std SI (mm)'};
rownames    = {'Left Vim','Right Vim'};
h           = figure('NumberTitle', 'off', 'Name', 'Centroid locations (world coordinates)');
tab1        = uitable(h,'Data',dat,'ColumnName',colnames,'RowName',rownames);

set(tab1,'Position',[20   0 1200 100]);set(h,   'position',[10 600 1200 100]);

% Summary of Centroid Properties
rms         = [lv.rms;      rv.rms      ];
mx          = [lv.ed.mx;    rv.ed.mx    ];
ap          = [lv.max.ap;   rv.max.ap   ];
ml          = [lv.max.ml;   rv.max.ml   ];
si          = [lv.max.si;   rv.max.si   ];

dat         = [rms mx ap ml si];
colnames    = {'RMS ED (mm)','Max ED (mm)','Max AP displacement (mm)','Max ML displacement (mm)','Max SI displacement (mm)'};
rownames    = {'Left Vim','Right Vim'};
h           = figure('NumberTitle', 'off', 'Name', 'Centroid Properties');
tab1        = uitable(h,'Data',dat,'ColumnName',colnames,'RowName',rownames);

set(tab1,'Position',[20   0 1200 100]);set(h,   'position',[10 400 1200 100]);

% Summary of HCP test-retest positions
lv1 = results.testretest.session1.left_vim;
lv2 = results.testretest.session2.left_vim;
rv1 = results.testretest.session1.right_vim;
rv2 = results.testretest.session2.right_vim;
x   = [lv1.mean.ap;  lv2.mean.ap;rv1.mean.ap;    rv2.mean.ap];
y   = [lv1.mean.ml;  lv2.mean.ml;rv1.mean.ml;    rv2.mean.ml];
z   = [lv1.mean.si;  lv2.mean.si;rv1.mean.si;    rv2.mean.si];
xs  = [lv1.std.ap;   lv2.std.ap; rv1.std.ap;     rv2.std.ap];
ys  = [lv1.std.ml;   lv2.std.ml; rv1.std.ml;     rv2.std.ml];
zs  = [lv1.std.si;   lv2.std.si; rv1.std.si;     rv2.std.si];

dat            = [x xs y ys z zs];
colnames       = {'Mean AP','Std AP (mm)','Mean ML','Std ML (mm)','Mean SI','Std SI (mm)'};
rownames       = {'Left Vim: Session 1','Left Vim: Session 2','Right Vim: Session 1','Right Vim: Session 2'};
h              = figure('NumberTitle', 'off', 'Name', 'Test-retest centroid locations (world coordinates)');
tab1           = uitable(h,'Data',dat,'ColumnName',colnames,'RowName',rownames);

set(tab1,'Position',[20   0 1200 100]);set(h,   'position',[10 600 1200 100]);

% Summary of Tract vs Surgery
lv      = results.centroid_tractography.left_vim.surgicaldifference;
rv      = results.centroid_tractography.right_vim.surgicaldifference;
rms     = [lv.rms;      rv.rms     ];
mx      = [lv.ed.mx;    rv.ed.mx   ];
ap      = [lv.max.ap;   rv.max.ap  ];
ml      = [lv.max.ml;   rv.max.ml  ];
si      = [lv.max.si;   rv.max.si  ];

dat            = [rms mx ap ml si];
colnames       = {'RMS ED (mm)','Max ED (mm)','Max AP displacement (mm)','Max ML displacement (mm)','Max SI displacement (mm)'};
rownames       = {'Left Vim','Right Vim'};
h              = figure('NumberTitle', 'off', 'Name', 'Tract vs Surgical targeting displacement');
tab1           = uitable(h,'Data',dat,'ColumnName',colnames,'RowName',rownames);

set(tab1,'Position',[20   0 1200 100]);set(h,   'position',[10 200 1200 100]);

%% Recreate rendering
renderthalamus(l_surf,r_surf,results,Affine,output);

%% Plot the principal directions from Covariance matrix
eigenplots(results,output);

%% Recreate plots
h  = figure('NumberTitle', 'off', 'Name', 'Centroid plot');
lv = results.centroid_tractography.left_vim.data;
rv = results.centroid_tractography.right_vim.data;

scatter3(lv.ap,lv.ml,lv.si,'r','filled');hold on; axis image;
scatter3(rv.ap,rv.ml,rv.si,'g','filled');

xlabel('Anterior-posterior');ylabel('Medial-lateral');zlabel('Superior-inferior'); % Check that X and Y are not swapped

h  = figure('NumberTitle', 'off', 'Name', 'Centroid plot with surgical targets');
scatter3(lv.ap,lv.ml,lv.si,'b','filled');hold on; axis image;
scatter3(rv.ap,rv.ml,rv.si,'b','filled');

lv  = results.centroid_surgical.left_vim.data;
rv  = results.centroid_surgical.right_vim.data;

scatter3(lv.ap,lv.ml,lv.si,'r','filled');
scatter3(rv.ap,rv.ml,rv.si,'r','filled');
xlabel('Anterior-posterior');ylabel('Medial-lateral');zlabel('Superior-inferior'); % Check that X and Y are not swapped

%% Raincloud plot
vim_raincloud_plot(results,options);

%% Return everything and save
save(fullfile(output,'vim_results_array'),'results');
UD          = char(strcat('Complete:',datestr(now)));disp(UD);logfile=char(logfile,UD);
filename    = (fullfile(output,'logfile.txt'));writelog(filename,logfile);
end
%==========================================================================

%==========================================================================
function s = do_fstat(y,X)
c = [1 0 0 0; 0 1 0 0; 0 0 1 0]; % Contrast vector/matrix
X = [X ones(size(X,1),1)];       % Design matrix
[s.p,s.F,s.nu] = fstat(X,y,c);   % Run F test (as in SPM)
end
%==========================================================================

%==========================================================================
function [p,F,nu] = fstat(X,y,c)
% F statistic
X0 = X*null(c);
nu = [rank(X)-rank(X0), size(X,1)-rank(X)];
t1 = y'*(y - X0*(X0\y));
t2 = y'*(y - X*(X\y));
F  = (t1-t2)/t2 * nu(2)/nu(1);
p  = 1-spm_Fcdf(F,nu);
end
%==========================================================================

%==========================================================================
function p=pitmanmorgantest(x,y)
%% Test the Difference Between Correlated Variances
% Adapted from Gardner, R.C. (2001). Psychological Statistics Using SPSS
% for Windows. New Jersey: Prentice Hall (p57)
x       = x(:);% Make sure data correctly orientated
y       = y(:);
N       = size(x,1);
vx      = sort([var(x),var(y)],'descend'); %vx(1)-vx(2) must be +'ve
c       = corr(x,y);
tval    = (vx(1)-vx(2))*sqrt(N-2)/sqrt((prod([4 vx])*(1-c^2))); %actual pm test
p       = 2*(1-tcdf(tval,(N-2)));
end
%==========================================================================

%==========================================================================
function writelog(filename,logfile)
fo  = fopen(filename,'w');
for ii=1:size(logfile,1)
    fprintf(fo,'%s\n',deblank(logfile(ii,:)));
end
fclose(fo);
end
%==========================================================================

function eigenplots(data,output)
figure('NumberTitle', 'off', 'Name', 'Centroid covariance eigendecomposition');
set(gcf,'color','w');
material metal;

%% Some figure options
% For surf:
fig.alpha       = 0.75;
fig.colmap      = 'summer'; %They look like olives...
fig.shading     = 'interp';
fig.material    = 'metal';
fig.lighting    = 'phong';
fig.camlight    = 'headlight';

% axis scaling: make the distance between the ellipsoids appear closer
% along ML by switching from mm scale to cm scale.
fig.scale_ml = 0.1;

%For plotting principal directions
fig.linetype    = {'k-', 'k--', 'k:'} ;%For plotting principal directions
fig.linewidth   = 2;%For plotting principal directions
fig.maxheadsize = 0.5; %For quiver arrow size

for hemisphere=1:2
    % Do left and then right
    if hemisphere==1
        S   = data.centroid_tractography.left_vim.Sig;
        ap  = data.centroid_tractography.left_vim.mean.ap;
        ml  = data.centroid_tractography.left_vim.mean.ml;
        si  = data.centroid_tractography.left_vim.mean.si;
    else
        S   = data.centroid_tractography.right_vim.Sig;
        ap  = data.centroid_tractography.right_vim.mean.ap;
        ml  = data.centroid_tractography.right_vim.mean.ml;
        si  = data.centroid_tractography.right_vim.mean.si;
    end
    
    %Eigendecompose the covariance matrix
    [v,l]   = eig(S);
    
    % Sorted in descending eigenvalues
    [~, l_idx] = sort(diag(l), 'descend');
    l = l(l_idx,l_idx);
    v = v(:,l_idx);
    
    %Make an ellisoid glyph: axis lengths proportional to square root of
    %eigenvalues
    [X,Y,Z] = ellipsoid(0,0,0,sqrt(l(1,1)),sqrt(l(2,2)),sqrt(l(3,3)),500); %Overkill for smooth pic
    
    for x = 1:size(X,1)
        for y = 1:size(X,2)
            A       = [X(x,y) Y(x,y) Z(x,y)]';
            A       = v*A;
            X(x,y)  = A(1);
            Y(x,y)  = A(2);
            Z(x,y)  = A(3);
        end
    end
    
    %Make surface, move to world space average coordinates
    surf(X+ap,Y+ml*fig.scale_ml,Z+si,'FaceAlpha',fig.alpha);
    shading(fig.shading);lighting(fig.lighting);hold on;colormap(fig.colmap);
    %Set up correct aspace ratio
    axis image;
    
    %Add principal directions
    for i = 1:3
        %Scale principal direction by sqrt of eigenvalue of covariance
        %matrix
        scaled_v = sqrt(l(i,i))*v(:,i);
        
        quiver3(ap, ml*fig.scale_ml, si, scaled_v(1), scaled_v(2), scaled_v(3), fig.linetype{i},'LineWidth',fig.linewidth, 'MaxHeadSize', fig.maxheadsize, 'AutoScale', 'off');
        quiver3(ap, ml*fig.scale_ml, si, -scaled_v(1), -scaled_v(2), -scaled_v(3), fig.linetype{i},'LineWidth',fig.linewidth, 'MaxHeadSize', fig.maxheadsize, 'AutoScale', 'off');
    end
end

%% Annotate and save
ylabel('Medial-Lateral (cm)');xlabel('Anterior-posterior (mm)');zlabel('Superior-inferior (mm)');
camlight(fig.camlight)

view(0,90);
filename=fullfile(output,['eigenglyph_',date,'_axial-superior']);
print(filename,'-djpeg','-r300')

view(-90,0);
filename=fullfile(output,['eigenglyph_',date,'_anterior']);
print(filename,'-djpeg','-r300')

view(0,0);
filename=fullfile(output,['eigenglyph_',date,'_leftlateral']);
print(filename,'-djpeg','-r300')

view(70,10)
filename=fullfile(output,['eigenglyph_',date,'_jaunty']);
print(filename,'-djpeg','-r300')
end
%==========================================================================

%==========================================================================
function renderthalamus(l_surf,r_surf,results,Affine,output)
%%Generate L,R then both - Keep the latter open to explore. Bit cluncky but
%fine for regnerating results.

% Sort out world coordinates:
lv      = cell2mat(struct2cell(results.centroid_tractography.left_vim.data)');
lv      = Affine(1:3,1:3)*([lv(:,2) lv(:,1) lv(:,3)]')+Affine(1:3,4);lv=lv';
rv      = cell2mat(struct2cell(results.centroid_tractography.right_vim.data)');
rv      = Affine(1:3,1:3)*([rv(:,2) rv(:,1) rv(:,3)]')+Affine(1:3,4);rv=rv';
lvs     = cell2mat(struct2cell(results.centroid_surgical.left_vim.data));
lvs     = Affine(1:3,1:3)*([lvs(2) lvs(1) lvs(3)]')+Affine(1:3,4);
rvs     = cell2mat(struct2cell(results.centroid_surgical.right_vim.data));
rvs     = Affine(1:3,1:3)*([rvs(2) rvs(1) rvs(3)]')+Affine(1:3,4);

% Do left
clear matlabbatch
matlabbatch{1}.spm.tools.render.SRender.Object(1).SurfaceFile(1)            = cellstr(l_surf);
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Red                 = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Green               = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Blue                = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(1).DiffuseStrength           = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).AmbientStrength           = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularStrength          = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularExponent          = 10;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularColorReflectance  = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).FaceAlpha                 = 0.2;
spm_jobman('run',matlabbatch);camzoom(0.9)

h=gcf;axis on;hold on
scatter3(lv(:,1),lv(:,2),lv(:,3),'b','filled');
scatter3(lvs(1),lvs(2),lvs(3),'r','filled');
xlabel('Medial-Lateral');ylabel('Anterior-posterior');zlabel('Superior-inferior'); % Check that X and Y are not swapped

%Lets do a few canonical views and save:
%% 1. Superior-inferior -> Coronal
view(0,90)
filename    = fullfile(output,['left-vim_',date,'_axial-superior']);
print(filename,'-djpeg','-r300')

view(90,0)
filename    = fullfile(output,['left-vim_',date,'_sagittal-right']);
print(filename,'-djpeg','-r300')

view(-90,0)
filename    = fullfile(output,['left-vim_',date,'_sagittal-left']);
print(filename,'-djpeg','-r300')

view(0,0)
filename    = fullfile(output,['left-vim_',date,'_axial-anterior']);
print(filename,'-djpeg','-r300')
close(h)

% Do right
clear matlabbatch
matlabbatch{1}.spm.tools.render.SRender.Object(1).SurfaceFile(1)            = cellstr(r_surf);
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Red                 = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Green               = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Blue                = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).DiffuseStrength           = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).AmbientStrength           = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularStrength          = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularExponent          = 10;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularColorReflectance  = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).FaceAlpha                 = 0.2;
spm_jobman('run',matlabbatch);
camzoom(0.9)

h=gcf;axis on;hold on
scatter3(rv(:,1),rv(:,2),rv(:,3),'b','filled');
scatter3(rvs(1),rvs(2),rvs(3),'r','filled');
xlabel('Medial-Lateral');ylabel('Anterior-posterior');zlabel('Superior-inferior'); % Check that X and Y are not swapped

%Lets do a few canonical views and save:
%% 1. Superior-inferior -> Coronal
view(0,90)
filename    = fullfile(output,['right-vim_',date,'_axial-superior']);
print(filename,'-djpeg','-r300')

view(90,0)
filename    = fullfile(output,['right-vim_',date,'_sagittal-right']);
print(filename,'-djpeg','-r300')

view(-90,0)
filename    = fullfile(output,['right-vim_',date,'_sagittal-left']);
print(filename,'-djpeg','-r300')

view(0,0)
filename    = fullfile(output,['right-vim_',date,'_axial-anterior']);
print(filename,'-djpeg','-r300')
close(h)

%Both - Keep this open
clear matlabbatch
matlabbatch{1}.spm.tools.render.SRender.Object(1).SurfaceFile(1)            = cellstr(l_surf);
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Red                 = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Green               = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(1).Color.Blue                = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(1).DiffuseStrength           = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).AmbientStrength           = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularStrength          = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularExponent          = 10;
matlabbatch{1}.spm.tools.render.SRender.Object(1).SpecularColorReflectance  = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(1).FaceAlpha                 = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(2).SurfaceFile(1)            = cellstr(r_surf);
matlabbatch{1}.spm.tools.render.SRender.Object(2).Color.Red                 = 0;
matlabbatch{1}.spm.tools.render.SRender.Object(2).Color.Green               = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(2).Color.Blue                = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(2).DiffuseStrength           = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(2).AmbientStrength           = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(2).SpecularStrength          = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Object(2).SpecularExponent          = 10;
matlabbatch{1}.spm.tools.render.SRender.Object(2).SpecularColorReflectance  = 0.8;
matlabbatch{1}.spm.tools.render.SRender.Object(2).FaceAlpha                 = 0.2;
matlabbatch{1}.spm.tools.render.SRender.Light.Position                      = [100 100 100];
matlabbatch{1}.spm.tools.render.SRender.Light.Color.Red                     = 1;
matlabbatch{1}.spm.tools.render.SRender.Light.Color.Green                   = 1;
matlabbatch{1}.spm.tools.render.SRender.Light.Color.Blue                    = 1;
spm_jobman('run',matlabbatch);

h=gcf;hold on;axis on;
scatter3(lv(:,1),lv(:,2),lv(:,3),'b','filled');scatter3(rv(:,1),rv(:,2),rv(:,3),'b','filled');
scatter3(lvs(1),lvs(2),lvs(3),'r','filled');scatter3(rvs(1),rvs(2),rvs(3),'r','filled');
xlabel('Medial-Lateral');ylabel('Anterior-posterior');zlabel('Superior-inferior'); % Check that X and Y are not swapped
camzoom(0.9)

view(0,0)
filename=fullfile(output,['joint-vim_',date,'_axial-anterior']);
print(filename,'-djpeg','-r300')

view(0,90)
filename=fullfile(output,['joint-vim_',date,'_axial-superior']);
print(filename,'-djpeg','-r300')
end
%==========================================================================

%==========================================================================
function vim_raincloud_plot(data,options)
%% Produce raincloud plot from centroids
figure('NumberTitle', 'off', 'Name', 'Raincloud plot: Vim Centroids');
set(gcf,'color','w');count=0;

% Set a few options
labs                = char('AP','ML','SI');
wdth                = 0.75; % width of boxplot
pos                 = -0.5; %Y-axis centre of boxplot
pp                  = [1;3;5;2;4;6]; %Sub-plot order
xlimits{1,1}        = [-24,-10]; xlimits{1,2}   = [-24,-10];
xlimits{2,1}        = [-19,-8]; xlimits{2,2}    = [8,19];
xlimits{3,1}        = [-2,10]; xlimits{3,2}      = [-2,10];

for hemisphere=1:2
    % Do left and then right
    if hemisphere==1
        tmp         = data.centroid_tractography.left_vim.data;
        surgical    = data.centroid_surgical.left_vim.data;
        side        = 'Left';
    else
        tmp         = data.centroid_tractography.right_vim.data;
        surgical    = data.centroid_surgical.right_vim.data;
        side        = 'Right';
    end
    
    X               = (options.affine(1:3,1:3)*[tmp.ml tmp.ap tmp.si]')+options.affine(1:3,4); %Voxel to world, results in mm
    X               = [X(2,:);X(1,:);X(3,:)]; %Re-order just to keep consistent accross work. Makes it easier to follow/error check
    Sx              = (options.affine(1:3,1:3)*[surgical.ml surgical.ap surgical.si]')+options.affine(1:3,4);
    Sx              = [Sx(2,:);Sx(1,:);Sx(3,:)];
        N                   = size(X,2);                          % Number of samples

    for k = 1:3
        % Create pdf from data
        [a,b]       = ksdensity(X(k,:));
        a           = a./max(a);%normalise to 0-1
        
        % Initiate subplot
        count       = count+1; subplot(3,2,pp(count));
        
        % Add density plot
        area(b,a,'FaceColor', options.col(k,:), 'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 2);hold on;
        
        title(char(strcat(side,32,'Vim:',32,labs(k,:))));
        
        % Add mean tract centroids
        mup         = repmat(mean(X(k,:)),120,1); plot(mup,(0.0:0.01:1.19),'k-');hold on;
        
        % Add mean sugical centroids
        mup         = repmat(mean(Sx(k,:)),120,1); plot(mup,(0.0:0.01:1.19),'k--');hold on;
        
        % make some space under the density plot for the boxplot
        ylim([-1 1.1]);xlim(xlimits{k,hemisphere});
        
        % jitter for scatter plot
        jit         = (rand(size(X(k,:))) - 0.5) * wdth;
        
        % Add scatter plot
        scatter(X(k,:),jit + pos,'MarkerFaceColor',options.col(k,:),'MarkerEdgeColor','k','SizeData',15);hold on;
        
        % info for making boxplot in paper: Quartiles, mean, 2*sd
        Y           = [quantile(X(k,:),[0.25 0.75]) mean(X(k,:)) mean(X(k,:))-2*(std(X(k,:))) mean(X(k,:))+2*(std(X(k,:)))];
        
        % Add box:
        rectangle('Position',[Y(1) pos-(wdth*0.5) Y(2)-Y(1) wdth],'EdgeColor','k','LineWidth',2);hold on
        
        % Add mean:
        line([Y(3) Y(3)],[pos-0.4 pos+0.4],'col','k','LineWidth',2);hold on
        
        % Add std:
        line([Y(2) Y(5)],[pos pos],'col','k','LineWidth',2);hold on
        line([Y(1) Y(4)],[pos pos],'col','k','LineWidth',2);hold on
        
        % Tidy up axis
        set(gca,'ytick',[]);set(gca,'yticklabel',[]);
    end
end
%Save the output
output              = fullfile(options.pth,'results');
filename            = fullfile(output,['raincloud-plot_',date,'_vim-centroids']);
print(filename,'-djpeg','-r300');
end