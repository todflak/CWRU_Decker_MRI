clear all;
close all;
tvalue = 15;
dicomdir = 'C:\Users\todfl\Documents\Decker\MRI Processing\Raw Data\WPAFB HyperO2\CW013\raw\';
frontname = 'RESEARCH_CW013_03092018.MR.SEQUENCEREGION_MARCIE.0012';
dicomlist = dir([dicomdir frontname '*.*']);

% make one figure with all slices
figure, 
for i = 1:length(dicomlist)
    imtmp = dicomread([dicomdir dicomlist(i).name]);
    CBF(:,:,i) = (imtmp(:,:)-2048)./5;
    subplot(4,4,i), imagesc(CBF(:,:,i)), colormap(hot), caxis([0 100]), title(['CBF Slice ', num2str(i)]); colorbar 
end;