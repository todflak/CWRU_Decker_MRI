% This script modified from original "batch_realign.m" from ASLtbx.
% The original version of this script called "spm_realign_asl", which was 
% a modification by Ze Wang of the "spm_realign" code; he wrote: "The
% modification is to remove the artifical motion component caused by the
% systematical label/control signal modulations in arterial spin labeled
% perfusion MRI."  That artifical motion seems to be caused by the
% difference in the fields in the label versus control image, and it is
% apparent just by flipping through the raw ASL series.  I don't really 
% understand his code; however, I think that modification he made is not 
% sufficient.  I think he is still doing a mostly rigid-body
% transformation.  The additional problem that I think still remains is
% that the distortions are not uniform, so that if the subject moves
% slightly, the distortions affect the image differently in different
% areas. Therefore we need to warp the image slightly when the subject
% moves, to correct for the non-uniform distortions.  This seems like a
% perfect job for the SPM Realign & Unwarp functionality.
% Tod Flak 11 Nov 2019

% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
% Batch realigning images.
% Get the global subject information

% clear
global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Performing motion correction & unwarp of ASL series\n', datestr(datetime('now')));      
par;

disp('Performing motion correction & unwarp of ASL series for all subjects, just wait....');

spm_jobman('initcfg') ;


% get the subdirectories in the main directory
for sb =1:PAR.nsubs % for each subject

   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',sb, c,PAR.subjects{sb},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
      disp(str);
      % get files in this directory

      clear matlabbatch;

      Ptmp=spm_select('ExtFPList',PAR.condirs{sb,c},['^' PAR.confilters{c} '\w*\.nii$'],1:400);
      
      nrun = 1; % enter the number of runs here
      [CodePath,nam,ext,num] = spm_fileparts(mfilename('fullpath')); %#ok<ASGLU>
      jobfile = {[CodePath '\CWRU_realign_unwarp_job.m']};
      jobs = repmat(jobfile, 1, nrun);
      inputs = cell(0, nrun);
      
      
      %I am considering moving back to processing all ASL conditions
      %together in one call to the realign & unwarp code, as was done in
      %the original ASLtbx code; but unfortunately I cannot really figure
      %out the sybtax to pass as the "inputs" variable to make this work.
      %You can see the several ways I attempted below.  For now, just go
      %with this way that works for processing one ASL series at a time.
      %In the future, if I really want to do it, I could always create the
      %'matlabbatch' object myself here in the code, and directly assign
      %the 'matlabbatch{X}.spm.spatial.realignunwarp.data.scans' objects in
      %a loop.... that should work.  TF 12 Nov 2019
%       for crun = 1:nrun
%          inputs{1, crun} = Ptmp;
%       end
    %  inputs=Ptmp;
    %  inputs{1,1} = struct('scans', '', 'pmscan', '');
    %  inputs{1,1}.scans = cellstr(Ptmp);
        inputs{1,1} = cellstr(Ptmp);
        spm('defaults', 'FMRI');
        spm_jobman('run', jobs, inputs{:});
      
        [pth,nam,ext,num] = spm_fileparts(Ptmp(1,:));
        movefil = spm_select('FPList', pth, ['^rp_.*\w*.*\.txt$']);
      
     %the original 'batch_realign' code produced a mean file named
     %'meanPASL.nii'; but it seems that this realign&unwarp process
     %produces 'meanrPASL.nii'; so to make this consistent with previous
     %version, remove the 'r' from the mean image filename.
 
     meanfile_r =  spm_select('FPList', pth, ['meanr' nam ext]);
     meanfile = fullfile(pth,['mean' nam ext]);
     movefile( meanfile_r, meanfile);
        
        fprintf(fidLog,'   Produced coregistered PASL series file: %s\n',fullfile(pth,['r' nam ext]) );      
        fprintf(fidLog,'   From that, produced average PASL file: %s\n', meanfile );      
        fprintf(fidLog,'   Also saved movement file: %s\n',movefil );      
   end
end

