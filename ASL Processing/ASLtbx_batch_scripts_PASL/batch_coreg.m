% coregistration meanPASL, rPASL, and rM0 to structural image
%

global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Coregister ASL images to structural images for all subjects\n', datestr(datetime('now')));
par;

disp('Coregister ASL images to structural images for all subjects, it takes a while....');
global defaults;
defaults=spm_get_defaults;  %spm_defaults;
flags = defaults.coreg;

% dirnames,
% get the subdirectories in the main directory
for s = 1:length(PAR.subjects) % for each subject
   fprintf(fidLog, 'Now coregister %s''s data with structural image\n',char(PAR.subjects{s}));

   %PG - Tar(G)et image, NEVER CHANGED
   %PF - Source image, transformed to match PG
   %PO - (O)ther images, originally realigned to PF and transformed again to PF
   
   % TARGET
   % get (NOT skull stripped structural from) Structurals
   %PG = spm_get('Files', dir_anat,[PAR.structprefs '*.nii']);
   PG=spm_select('FPList',PAR.structdir{s},['^' PAR.structprefs '\w*.*\.nii$']);
   PG=PG(1,:);
   VG = spm_vol(PG);
   
   for c=1:PAR.ncond
      clear PF VF PO
      
      %SOURCE is the meanPASL.nii image
      PF = spm_select('FPList', char(PAR.condirs{s,c}),['^mean' PAR.confilters{1} '\w*\.nii$']);
      PF=PF(1,:);
      VF = spm_vol(PF);
      
      %do coregistration
      %this method from spm_coreg_ui.m
      %get coregistration parameters
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
      x  = spm_coreg(VG, VF,flags.estimate);
      
      %get the transformation to be applied with parameters 'x'
      M  = inv(spm_matrix(x));
      %transform the mean image
      %spm_get_space(deblank(PG),M);
      
      %Now get the list of images we want to transform
      PO=[];
      %Fixed the last part of the regex filters in these two selects.
      %Orginal was  '\w.*nii' .  TF 24 Aug 2017
      Ptmp=spm_select('EXTFPList', char(PAR.condirs{s,c}), ['^oe_r' PAR.confilters{c} '\w*\.nii$'], 1:1000);
      PO=strvcat(PO,Ptmp);
                                 
      Ptmp=spm_select('EXTFPList', char(PAR.M0dirs{s,c}), ['^r' PAR.M0filters{c}  '\w*\.nii$'], 1:1000);
      PO=strvcat(PO,Ptmp);
      
      %PO = PF; --> this if there are no 'other' images
      if isempty(PO) || strcmp(PO,'/')
         PO=PF;
      else
         PO = strvcat(PF,PO);
      end
            
      %in MM we put the transformations for the 'other' images
      MM = zeros(4,4,size(PO,1));
      for j=1:size(PO,1)
         %get the transformation matrix for every image
         MM(:,:,j) = spm_get_space(deblank(PO(j,:)));
      end
      
      strPreviousFilename = '';
      for j=1:size(PO,1)
         %write the transformation applied to every image
         %filename: deblank(PO(j,:))
         spm_get_space(deblank(PO(j,:)), M*MM(:,:,j));
         [pth,nam,ext,num] = spm_fileparts(deblank(PO(j,:)));
         strFilename = fullfile(pth,[nam ext]);
         if ~strcmp(strFilename, strPreviousFilename)   %avoid listing all indexes of 4D Nii
            fprintf(fidLog,'   Applied transformation matrix to file: %s\n', strFilename );    
            strPreviousFilename = strFilename;
         end
      end
      
   end
end