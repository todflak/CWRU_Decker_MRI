function   ASLtbx_asltemporalfiltering(P, maskimg, opt, maskimgs)
% temporal filtering. Assuming the ASL images are acquired in an order of label control label control ...
% opt -- if not set, just regress out motions
%      -- 1: regress out global signal
%      -- 2: regress out nuisances to be defined by the first mask image in the array: maskimgs
%      -- 3: regress out global signal and other nuisances (to be defined by the mask images, eg, csf or white matter signal)
%      -- 


global fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen

if isempty(P), fprintf(fidLog, 'Input images don''t exist!\n'); return; end;
[pth,nam,ext,num] = spm_fileparts(P(1,:));
% getting the motion correction results. Assuming it is located in the same folder as the images
 movefil = spm_select('FPList', pth, ['^oe_rp_.*\w*.*\.txt$']);
 moves = spm_load(movefil);
 if (size(moves,2)>6)  %This condition added by TF 12 Nov 2019.  In original ASLtbx
     %code, the file 'rp_PASL.txt' was produced by the code in
     %'spm_realiang_asl.m', which was Ze Wang re-write of the original
     %spm_realign.  The spm_realign normally produces a text file
     %'rp_*.txt' which records the 6-axis movement required for realignment
     %of each image.  In Ze Wang's re-write of that code, he still outputs
     %the same as the original spm_realign; but he also outputs another 6
     %columns.   His idea in his 'spm_realign_asl' code was to move the
     %images in pairs -- so, after the basic spm_realign algorithm, he
     %looked at the average of all movements; then he subtracted that
     %movement from all the 'label' images, and added something to the
     %'control' images... honestly, I don't really comprehend what we is
     %doing, but it is something related to treating the label and control
     %images as two groups.  Anyway, with our new
     %'CWRU_batch_realing_unwarp'  I am not doing any of that
     %monkey business -- whatever 'spm_realign' did was OK for me.  
     
     %So, if the file has only 6 columns, just use as it is; if it has 12
     %columns (actually, if more than 6), use columns 7-12 as the
     %movements.
     %In the end, I am wondering if this is even valid anymore, since my
     %'CWRU_batch_realing_unwarp' code is doing spm_realign and then also
     %doing an "unwarp".  So the total movement is different than in the
     %simple realign resolts.  But I don't understand this temporal
     %filtering code well enough to comprehend how I ought to use the
     %results of the unwarp here... so just go head with the use of the
     %rigid realign results.  TF 12 Nov 2019
     
     moves = moves(:,7:12);
 end
 % reading data
 v=spm_vol(P);
 dat=spm_read_vols(v);
 [sx,sy,sz,st]=size(dat);
 if st~=size(moves,1)
     fprintf(fidLog, 'Something wrong happened during motion correction.\n');
     fprintf(fidLog, 'Number of images selected here: %d is different from \n', st);
     fprintf(fidLog,'     the number of images: %d in motion correction. \n', size(moves, 1));
     return;
 end
 dat(isnan(dat))=0;
 mimg=squeeze(mean(dat,4));
 dat=dat - repmat(mimg, [1, 1, 1, st]);
 if nargin<2 || isempty(maskimg)
     mask=mimg>0.23*max(mimg(:));
else    
     vm=spm_vol(maskimg);
     mask=spm_read_vols(vm);
     mask=mask>0;
end

orgdat=reshape(dat, sx*sy*sz, st);
gs=mean(orgdat(mask(:), :), 1);

if nargin== 3 
    if isempty(maskimgs), nui=gs; 
    else
	    if opt==2
	       vm1=spm_vol(maskimgs(1,:));
	       mask1=spm_read_vols(vm1);
	       mask1=mask1>0;
	       nui = orgdat(mask1(:), :);
	    else
	       NN=size(maskimgs,1);
	       vm1=spm_vol(maskimgs);
	       mask1=spm_read_vols(vm1);
	       mask1=mask1>0;
	       mask1=reshape(mask1, sx*sy*sz, NN);
	       for nn=1:NN
	           nui=[nui; orgdat(mask1(:, nn), :)];
           end
        end
    end
else
     nui=[];	    
end
%  define the zigzag pattern
ref=-ones(st,1);  
ref(2:2:end)=1;
nui=[moves nui];      % concatenate motion timecourses and the other nuisances
mnui=mean(nui, 2);
nui = nui - repmat(mnui, 1, size(nui,2));
nui = nui - ref/(ref'*ref)*ref'*nui;      % clean up the zigzag pattern
[u,s,vec]=svd(nui);
Nnui=size(nui,2);    % number of nuisance vectors
% taking the first several eigen vectors which usually accounts for >90% of the variance
if Nnui>6
    nu=u(:, 1:6);
elseif Nnui>2
    nu=u(:, 1:2);    
elseif Nnui==1
    nu=u;
end    
%  regressing out the nuisances
dat=orgdat(mask(:), :);      %  only process the intracranial voxels
dat=dat-(dat*nu*nu');
nmat=mean(dat,2);
dat=dat-repmat(nmat,1,st);

[lb,la]=fltbutter(1,0.04,'high');  % high pass  
dat=filter(lb,la,dat,[],2); 
dat=repmat(nmat, 1, st) + dat;
orgdat(mask(:), :) = dat;
orgdat=reshape(orgdat, [sx sy sz st]);
orgdat=repmat(mimg, [1, 1, 1, st]) + orgdat;
% saving the filtered data
vo=v(1);
vo.fname=fullfile(pth, ['ASLflt_' nam '.nii']); 
vo.dt=[16 1];

%added by TF 26 Jun 2018; necessary if we change the number of images due to filtering
if (exist(vo.fname, 'file') ==2)
	% if there is already an 'ASLflt_' file, delete it
	delete(vo.fname);
end

for im=1:st
    vo.n=[im 1];
    vo=spm_write_vol(vo, squeeze(orgdat(:,:,:, im)));    
end

fprintf(fidLog,'   Produced temporal filtering results file: %s\n', vo.fname );    

return;