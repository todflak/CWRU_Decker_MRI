% Spatial normalization using the new segmentation algorithm
% This scripts include two step: estimation (brain segmentation) and writing. The first part can
% be used for structural image analysis such as VBM.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
%
% Get subject etc parameters
global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Normalize to TPM tissue segmentation model.\n', datestr(datetime('now')));
par;

close all;
global defaults;
defaults = spm_get_defaults;
defs = defaults.normalise;
PAR.SPM_path=spm('Dir');

% defs.write.vox= [1.5 1.5 1.5];

% defs.write.bb=[-84  -110   -60
%     84    80  85];
clear matlabbatch subs;

nP=[];
warp_files_toproduce=[];
warp_files_toreuse=[];

for s = 1:PAR.nsubs
   fprintf(fidLog, 'Batch normalization for subject %d....\n',s);
   P=spm_select('ExtFPList',PAR.structdir{s},['^' PAR.structprefs '.*\.nii$']);
   [pth,nam,ext,num] = spm_fileparts(P);
   matname = fullfile(pth, ['y_' nam '.nii']);
   if exist(matname , 'file')
      warp_files_toreuse=strvcat(warp_files_toreuse,matname);
   else
      nP=strvcat(nP, P);
      warp_files_toproduce=strvcat(warp_files_toproduce,matname);
   end
end
if ~isempty(warp_files_toreuse)
   fprintf(fidLog,'   Using previously produced warp of structure image(s) to TPM model: %s\n', char(warp_files_toreuse));
end

if ~isempty(nP)
   ASLtbx_spm12normest(nP);
   fprintf(fidLog,'   Produced warp of structure image(s) to TPM model: %s\n', char(warp_files_toproduce));
end

matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
   78 76 85];
matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
for s = 1:PAR.nsubs
   P = spm_select('FPList',PAR.structdir{s},['^' PAR.structprefs '.*\.nii$']);
   P = P(1,:);
   
   clear imgs  img_files_toproduce;
   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
            
      imgs{1,1}=spm_select('FPList', char(PAR.condirs{s,c}), ['^meanCBF.*\.nii']);
      %%% if you want to normalize the cbf image series, you can enable the
      %%% following lines
      %     cbfimgs=spm_select('EXTFPList', char(PAR.condirs{s,c}), ['^cbf_.*\.nii'], 1:1000);
      %     for i=1:size(cbfimgs,1)
      %         imgs{1+i,1}=deblank(cbfimgs(i,:));
      %     end
      
      % Make the default normalization parameters file name
      matname = fullfile(PAR.structdir{s}, ['y_' spm_str_manip(P,'dst') '.nii']);
      
      matlabbatch{1}.spm.spatial.normalise.write.subj.def{1} =matname;
      matlabbatch{1}.spm.spatial.normalise.write.subj.resample = imgs;
      cfg_util('run', matlabbatch);
      
      img_files_toproduce=[];
      for i=1:size(imgs,1)
         [pth,nam,ext,num] = spm_fileparts(char(deblank(imgs(i))));
         img_files_toproduce= strvcat(img_files_toproduce,fullfile(pth, ['w' nam  ext]));
      end
      fprintf(fidLog,'   For subject %d, condition %d, produced normalized meanCBF image: %s\n', s, c, char(img_files_toproduce));
   end
end
clear matlabbatch;