clear all;
close all;
clc

ShowGraphics=false;
UseMaskFile = false;
maskfilename =[];

DatasourceType = 'NII';  %set to DICOM or NII

dicomdir = 'C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\WPAFB prep\20171031\raw\';
frontname = 'RESEARCH_SD_TEST_DECKER.MR.SEQUENCEREGION_MARCIE.0378';

NiiFilename = 'C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\WPAFB\20171108\ASL\asl_4\PrecomputedCBF.nii';
maskfilename= 'C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\WPAFB\20171108\ASL\asl_4\brainmask.nii';
maskimagebinarythreshold=0.7;

switch DatasourceType 
   case 'DICOM'
      dicomlist = dir([dicomdir frontname '*.*']);
      CountSlices = length(dicomlist);
      % make one figure with all slices
      figure, 
      for i = 1:CountSlices
          imtmp = dicomread([dicomdir dicomlist(i).name]);
        %  CBF(:,:,i) = (imtmp(:,:)-2048)./5;

        %Note that the above line results in CBF being unsigned int. Being an "int" is no big problem (would be better to be a float).
        % But being "unsigned" forces all negative values are set to zero!
        % This also did not have bad implications, since we were previously always filtering for
        % values >10 or >20.
        %But would be better to cast this into a floating point type
        %  CBF(:,:,i) = (cast(imtmp(:,:),'single') -2048)./5;   %use cast to force to a floating point
          CBF(:,:,i) = cast(imtmp(:,:),'single').*0.20002441108226776 - 409.6000061035156;   %these constants are derived from the  Nii files "Data scaling"
             %the give nearly the same result at the -2048 and /5 in the original formula.  I
             %changed just so I could have exactly the same data from the DICOM as I have in the
             %Nii files, to make comparisons easier
          subplot(4,4,i), imagesc(CBF(:,:,i)), colormap(hot), caxis([0 100]), title(['CBF Slice ', num2str(i)]); colorbar 
      end;
      maskimagerotateangle = 90;  %the dicomread loads data with 90 degreee rotation relative to spm_read_vols

   case 'NII'
      vol_info = spm_vol(NiiFilename);
      CBF =  spm_read_vols(vol_info); 
      maskimagerotateangle = 0;   
      CountSlices = vol_info.dim(3);
      
end

GM10 = zeros(size(CBF));
GMCBF10 = zeros(1,CountSlices);

GM20 = zeros(size(CBF));
GMCBF20 = zeros(1,CountSlices);

UseMaskFile = false;
if (~isempty(maskfilename))
   maskimg = spm_read_vols(spm_vol(maskfilename));
   maskimg(isnan(maskimg))=0;  
   maskimg(maskimg<maskimagebinarythreshold )=0;  
   maskimg(maskimg>=maskimagebinarythreshold )=1;  
   UseMaskFile = true;
else
   maskimg = zeros(size(CBF));
end


for i = 1:CountSlices 
   if ShowGraphics
   	figure, imagesc(CBF(:,:,i)), colormap(jet), caxis([0 100]), title(['slice number ', num2str(i)]);
   end
   
   if (UseMaskFile)
      BW = maskimg(:,:,i);
      BW = imrotate(BW, maskimagerotateangle);
      maskimg(:,:,i) = BW;
    else
      BW = roipoly;
      maskimg(:,:,i) = BW;  %save for use later
   end  
    
    CBFmask(:,:,i) = cast(BW,'single').*CBF(:,:,i);

    %   [r,c] = find((CBFmask(:,:,i)>10));
    %   GM10(r,c,i) = CBFmask(r,c,i);
	
    %The lines above do not give the expected result!  
    %The "find((CBFmask(:,:,i)>10))" works as expected... returns row/column indices of values >10
    %However, the expression "CBFmask(r,c,i)" results in a weird matirx, whose size is size(r,1) by
    %  size(c,1).  For example, if there are 300 items in the r/c vectors, the expression "CBFmask(r,c,i)" 
    % results in a 300x300 matrix, the values of which are quite confusing!
    % Then, when you assign that into the GM10 matrix using the r & c vectors, you do not get the
    % expected results... many values that are less than 10 still appear.
	% In the end you sum all of these values (the proper ones AND the ones that should have been filtered
	% out), but then you divide by the original correct count of values.

    %A correct way to do this is:
    vals_thisslice = CBFmask(:,:,i);  %pull out just this current slice as a 2D array
    idx = find(vals_thisslice>10);  %get a vector of linear indices for values >10
    selectedvals_thisslice = zeros(size(vals_thisslice));
    selectedvals_thisslice(idx) =  vals_thisslice(idx); %copy the selected values
    GM10(:,:,i) = selectedvals_thisslice;
    n10(i) = length(idx);
    
    idx = find(vals_thisslice>20);  %get a vector of linear indices for values >20
    selectedvals_thisslice = zeros(size(vals_thisslice));
    selectedvals_thisslice(idx) =  vals_thisslice(idx); %copy the selected values
    GM20(:,:,i) = selectedvals_thisslice;
    n20(i) = length(idx);
        
    GMCBF10(i) = (sum(sum(GM10(:,:,i)))/n10(i));
    GMCBF20(i) = (sum(sum(GM20(:,:,i)))/n20(i));
    if isnan(GMCBF10(i))
        GMCBF10(i) = 0;
    end;
    if isnan(GMCBF20(i))
        GMCBF20(i) = 0;
    end;
end;

if ShowGraphics
   for i = 1:length(dicomlist)
       figure,
       subplot(1,3,1), imagesc(CBF(:,:,i)), colormap(hot), caxis([0 100]), title(['CBF Slice ', num2str(i)]); colorbar;
       subplot(1,3,2), imagesc(GM10(:,:,i)), colormap(hot), caxis([0 100]), title(['GM10 Slice ', num2str(i)]); colorbar;
       subplot(1,3,3), imagesc(GM20(:,:,i)), colormap(hot), caxis([0 100]), title(['GM20 Slice ', num2str(i)]); colorbar;
   end;
end

%compute mean of all within the brain mask
idx_mask = find(maskimg>0);
meanCBFAll = mean(CBF(idx_mask))

meanGMCBF10 = ((sum(GMCBF10.*n10))./sum(n10))
meanGMCBF20 = ((sum(GMCBF20.*n20))./sum(n20))

save('ASLDicom.mat','CBF', 'GM10', 'GM20', 'GMCBF10', 'GMCBF20', 'n10', 'n20');
