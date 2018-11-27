% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
% Batch calculation for the perfusion signals.
global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Calculate perfusion and CBF signals\n', datestr(datetime('now')));

%par;

% PAR.ASL_Quant_Params must be a vector of values to assign these parameters:
%  [Labeltime_ms Delaytime_ms  Slicetime_ms TE_ms Labeling_Efficiency SubtractionOrder]


for s = 1:PAR.nsubs % for each subject
   
   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
      
      P =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^sASLflt.*\.nii'], 1:1000 );
      maskimg=spm_select('FPList', PAR.condirs{s,c}, ['^brainmask\.nii']);
      
      % Corrected this next line .. there is no "sM0.nii" file, but there
      % is a "srM0.nii" (smoothed, co-registered).  TF 25 Aug 2017
%      M0img =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^sM0.*\.nii'],1:1000 );   
      M0img =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^srM0.*\.nii'], 1:1000 );
      % the asl_perf_subtract does not like the ",1" on end of the filename
      % returned by spm_select
      
      %          asl_perf_subtract(Filename,FirstimageType, SubtractionType,...
      %             SubtractionOrder,Flag,
      %             Timeshift,AslType,labeff,MagType,
      %             Labeltime,Delaytime,Slicetime,TE,M0img,M0roi,maskimg,
      %             M0csf,M0wm,threshold
      % Flag vector:
      %    Flag - flag vector composed of [MaskFlag,MeanFlag,CBFFlag,BOLDFlag,OutPerfFlag,OutCBFFlag,QuantFlag,ImgFormatFlag,D4Flag,M0wmcsfFlag]
      %        1.  MaskFlag - integer variable indicating whether perfusion images are
      %               masked by BOLD image series, usually, it's masked to remove the
      %               background noise and those non-perfusion regions.
      %               - 0:no mask; 1:masked
      %
      %        2.  MeanFlag - integer variable indicating whether mean image of all perfusion images are produced
      %               - 0:no mean image; 1: produced mean image
      %        3.  CBFFlag - indicator for calculating cbf. 1: calculated, 0: no
      %        4.  BOLDFlag - generate pseudo BOLD images from the tag-utag pairs.
      %        5.  OutPerfFlag: write perf signal to disk or not? 1 yes, 0:no
      %        6.  OutCBFFlag: write CBF signal to disk or not?
      %        7.  QuantFlag: using a unique M0 value for the whole brain? 1:yes, 0:no.
      %        8.  ImgFormatFlag: 0 (default) means saving images in Analyze format, 1 means using NIFTI
      %        9.  D4Flag       : 0 (default) - no, 1 - yes
      %       10.  M0wmcsfFlag: 1 - using M0csf to estimate M0b, 0 - using M0wm to estimate M0b, -1 - disabled
      %       11.  OutliersNANFlag: 1: set outlier to NaN in the CBF 4D images
  
      p = PAR.ASL_Quant_Params;
%  [Labeltime_ms Delaytime_ms  Slicetime_ms TE_ms Labeling_Efficiency SubtractionOrder]

      
      asl_perf_subtract(P, 0, 0, ...
         p(6),      [1 1 1 0 1 1 0 1 1 0 1 1],...  % was [1 1 1 0 0 1 0 1 1 0]
         0.5,     0,      p(5), 1,...
         p(1)/1000, p(2)/1000, p(3), p(4), M0img, [], maskimg);
      
      % fprintf(fidLog,'\n%40s%30s\n','',' ');
   end
end

