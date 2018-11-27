%Load the rotation information from Nii file.  Caller must choose to load
%info from the q-form or s-form.  No check is made to ensure that the
%selected form is denoted as being valid (i.e. if the Q-form code or S-form
%code is <>0)

function [quat, trans] = CWRU_Nii_load_rotation(niiFilename, whichform)
   hdr = load_untouch_header_only(niiFilename);
   hist = hdr.hist;
   
   switch whichform
      case 'q-form'
         a = sqrt(1.0-(hist.quatern_b^2 + hist.quatern_c^2 + hist.quatern_d^2));
         if ~isreal(a)  % avoid problem with slight rounding errors producing negative value  TF 26 Jan 2018
            a=0; 
         end  
         quat=quaternion([a; hist.quatern_b; hist.quatern_c; hist.quatern_d]); 
         trans=[hist.qoffset_x, hist.qoffset_y, hist.qoffset_z];
         
      case 's-form'
         rotmat = [hist.srow_x(1:3); hist.srow_y(1:3); hist.srow_z(1:3)];
         rotmat(:,3) =  rotmat(:,3) * hdr.dime.pixdim(1);  % apply the +1 or -1 qfac from pixdim(1)... maybe this is not necessary, because probably get the same quaterion regardless of sign... maybe?

         %factor out the pixdims from the rotmat to ensure determinant=1, 
         % which is required by the quaternion.rotationmatrix constructor
         pixdim_diag = diag(hdr.dime.pixdim(2:4));  %get the voxel dimensions, and put in a diagonal matrix
         rotmat_scaled = rotmat / pixdim_diag;
         %due to rounding errors, the determinant may be slightly different
         %from 1, so fix it.
         
         d = det(rotmat_scaled);
         if abs(d-1)>eps(16)   %if the error from 1 is greater than 1 unit of floating point space
            %found this code at: https://www.mathworks.com/matlabcentral/newsreader/view_thread/320730
            if d<0; rotmat_scaled(:,1)=-rotmat_scaled(:,1); d=-d; end;
            n=3;
            rotmat_scaled=(d^(-1/n))*rotmat_scaled;
         end
         quat =  quaternion.rotationmatrix(rotmat_scaled);
         trans = [hist.srow_x(4), hist.srow_y(4), hist.srow_z(4)];
         
      otherwise
         error('arguement ''whichform'' must be either ''q-form'' or ''s-form''');
   end
end
