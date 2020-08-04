% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
% Batch realigning images.
% Get the global subject information

% clear
global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Performing motion correction of ASL series\n', datestr(datetime('now')));      
par;

disp('Performing motion correction of ASL series for all subjects, just wait....');

% load spm defaults
global defaults;
defaults = spm_get_defaults;   %spm_defaults;

% Get realignment defaults
defs = defaults.realign;

% Flags to pass to routine to calculate realignment parameters
% (spm_realign)

%as (possibly) seen at spm_realign_ui,
% -fwhm = 5 for fMRI
% -rtm = 0 for fMRI
% for this particular data set, we did not perform a second realignment to
% the mean the coregistration between the reference control and label
% volume is also omitted
reaFlags = struct(...
    'quality', defs.estimate.quality,...  % estimation quality
    'fwhm', 5,...                         % smooth before calculation
    'rtm', 1,...                          % whether to realign to mean
    'PW',''...                            %
    );

% Flags to pass to routine to create resliced images
% (spm_reslice)
resFlags = struct(...
    'interp', 1,...                       % trilinear interpolation
    'wrap', defs.write.wrap,...           % wrapping info (ignore...)
    'mask', defs.write.mask,...           % masking (see spm_reslice)
    'which',2,...                         % write reslice time series for later use
    'mean',1);                            % do write mean image


% dirnames,
% get the subdirectories in the main directory
for sb =1:PAR.nsubs % for each subject
   P=[];
   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',sb, c,PAR.subjects{sb},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
      % get files in this directory
      Ptmp=spm_select('ExtFPList',PAR.condirs{sb,c},['^' PAR.confilters{c} '\w*\.nii$'],1:400);

      %P=strvcat(P,Ptmp);
      
      
      %This was originally set up to produce the mean image of ALL  (from
      %all conditions).  I modified to do each condition separately. 
      %TF 27 July 2017
      
      P=Ptmp;

      spm_realign_asl(P, reaFlags);
      % Run reslice
      spm_reslice(P, resFlags);
      [pth,nam,ext,num] = spm_fileparts(P(1,:));
      fprintf(fidLog,'   Produced coregistered ASL series file: %s\n',fullfile(pth,['r' nam ext]) );      
      fprintf(fidLog,'   From that, produced average ASL file: %s\n',fullfile(pth,['mean' nam ext]) );      
   end
end
