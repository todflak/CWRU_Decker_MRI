% coregistration meanPASL, rPASL, and rM0 to structural image
%

% TF 03 Aug 2020: I changed into a function, and added a param ASL_Type to 
% allow us to change behavior.  Previously, the coregistration was between
% the structural and the meanASL image; and then that transformation
% matrix was applied to the other images (rM0 and oe_rASL).  That works
% fine for Siemens PASL.  But with the new pCASL protocol we are using,
% there is so much static tissue suppression that the ASL images are very
% dim, and also there is a strong artifact from scalp fat that is of
% comparable intensity to the real image voxels; I am worried about using
% that mean ASL image.  I have decided that it would be better to use the
% rM0 for alignment to the structural image, then apply that alignment to
% all the required images.  However, I am exposing this option as a
% parameter to allow us to retain the original manner of doing this when
% processing PASL, if desired  (by default, if AlignSourceName_Regex is 
% empty, will default to meanPASL )
%

function batch_coreg(AlignSourceName_Regex)

   global PAR fidLog;
   if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
   
   
   if (exist('AlignSourceName_Regex','var')==0) || (isempty(AlignSourceName_Regex))
      AlignSourceName_Regex = ['^mean' PAR.confilters{1} '\w*\.nii$'];
   end  
   
   fprintf(fidLog,'\n%s: Coregister ASL images to structural images for all subjects\n', datestr(datetime('now')));



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

         %SOURCE is the meanASL.nii image
         PF = spm_select('FPList', char(PAR.condirs{s,c}),AlignSourceName_Regex);
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

         Ptmp=spm_select('EXTFPList', char(PAR.M0dirs{s,c}), ['^mean' PAR.confilters{1} '\w*\.nii$'], 1:1000);
         PO=strvcat(PO,Ptmp);

         %PO = PF; --> this if there are no 'other' images
         if isempty(PO) || strcmp(PO,'/')
            PO=PF;
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
end