function ASLtbx_smoothing(P, ker)

global fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen

if isempty(P), fprintf('No images have been provided!\n'); return; end
n=size(P,1);
nP=[];
Input3D=1;
if n==1
   [pth,nam,ext, num] = spm_fileparts(P);
   if isempty(num)
      v=spm_vol(P);
      for nimg=1:size(v,1)
         nP=strvcat(nP, [P ',' num2str(nimg)]);
      end
      Input3D=0;
   else
      nP=P;
      Input3D=1;
   end
else
   nP=P;
   Input3D=1;
end
simgs=[];

strPreviousFilename ='';

for im=1:size(nP,1)
   %this is actual image
   Pim=nP(im,:);
   [pth,nam,ext,num] = spm_fileparts(Pim);
   Qim=fullfile(pth,['s' nam '.nii' num]);
   strFilename = fullfile(pth,['s' nam '.nii']);
   %added by TF 26 Jun 2018; necessary if we change the number of images due to filtering
   if ((exist(strFilename, 'file') ==2) & (im==1))   %only delete when on the first time through the loop
	% if there is already an 's' file, delete it
	 delete(strFilename);
   end

   %now call spm_smooth with kernel defined at PAR
   spm_smooth(Pim,Qim,ker);
   simgs=strvcat(simgs, Qim);
   
   strFilename = fullfile(pth,['s' nam '.nii']);
   %avoid repeating report of incrementing image numbers
   if ~strcmp(strFilename, strPreviousFilename)
      fprintf(fidLog,'   Produced smoothed image file: %s\n',strFilename);
      strPreviousFilename = strFilename;
   end
end
%  the following part is to delete the intermediate 3D image series
if Input3D && n>1
   clear Qfname;
   for kk=1:size(simgs,1)
      Qfname{kk,1} = simgs(kk,:);
   end
   clear matlabbatch;
   
   matlabbatch{1}.spm.util.cat.vols = Qfname;
   [pth,nam,ext, num] = spm_fileparts(simgs(1,:));
   filename=fullfile(pth,['s' nam(1:6)  '_4D.nii']);
   matlabbatch{1}.spm.util.cat.name = filename;
   matlabbatch{1}.spm.util.cat.dtype = 4;
   cfg_util('run', matlabbatch);
   for im=1:size(simgs,1)
      delete(simgs(im,:));
      %eval(['!rm -f ' Qf(im,:)]);
   end
end