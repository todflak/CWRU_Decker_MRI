% batch file to do coregistration between mean BOLD and M0
%
global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Coregister M0 to meanASL\n', datestr(datetime('now')));
par;

disp('Coregister M0 to meanASL for all subjects, it takes a while....');
global defaults;
defaults=spm_get_defaults;
%spm_defaults;
flags = defaults.coreg;
resFlags = struct(...
   'interp', 1,...                       % trilinear interpolation
   'wrap', flags.write.wrap,...           % wrapping info (ignore...)
   'mask', flags.write.mask,...           % masking (see spm_reslice)
   'which',1,...                         % write reslice time series for later use, don't write the first 1
   'mean',0);                            % do write mean image
% dirnames,
% get the subdirectories in the main directory
for s = 1:length(PAR.subjects) % for each subject
   %take the dir where the mean image (reslice) is stored (only first condition)
   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
     
      dir_fun = PAR.condirs{s,c};
      %take the structural directory
      
      % get mean in this directory
      %PG - Tar(G)et image, NEVER CHANGED
      %PF - Source image, transformed to match PG
      %PO - (O)ther images, originally realigned to PF and transformed again to PF
      
      % TARGET
      % get (NOT skull stripped structural from) Structurals
      PG = spm_select('FPList', dir_fun, ...
         ['^mean' PAR.confilters{c} '\w*\.nii$']);
      PG=PG(1,:);
      VG = spm_vol(PG);
      
      %SOURCE, M0 image here
      PF=spm_select('FPList',PAR.M0dirs{s,c}, ['^' PAR.M0filters{c} '\w*\.nii$']);
      PF=PF(1,:);
      VF = spm_vol(PF);
      
      %This next line commented out by TF 24 Aug 2017.  Seems not necessary
      %to select the rM0.nii, if it exists... we are about to produce that
      %file
  %    PO=spm_select('EXTFPList', char(PAR.M0dirs{sb,c}),  ['^r' PAR.M0filters{c} '.*nii'], 1:1000);
      PO=[];      

      %PO = PF; --> this if there are no 'other' images
      if isempty(PO)
         PO=PF;
      else
         PO = strvcat(PF,PO);
      end
      
      %do coregistration
      %this method from spm_coreg_ui.m
      %get coregistration parameters
      x  = spm_coreg(VG, VF,flags.estimate);
      
      %get the transformation to be applied with parameters 'x'
      M  = inv(spm_matrix(x));
      %transform the mean image
      %spm_get_space(deblank(PG),M);
      %in MM we put the transformations for the 'other' images
      MM = zeros(4,4,size(PO,1));
      for j=1:size(PO,1)
         %get the transformation matrix for every image
         MM(:,:,j) = spm_get_space(deblank(PO(j,:)));
      end
      for j=1:size(PO,1)
         %write the transformation applied to every image
         %filename: deblank(PO(j,:))
         spm_get_space(deblank(PO(j,:)), M*MM(:,:,j));
      end
      P=strvcat(PG,PO);
      spm_reslice_flt(P,resFlags);   % creating the rM0 image
      
      for i=2:size(P,1)
         [pth,nam,ext,num] = spm_fileparts(P(i,:));
         fprintf(fidLog,'   Produced coregistered M0 file: %s\n',fullfile(pth,['r' nam ext]) );
      end
   end
end
