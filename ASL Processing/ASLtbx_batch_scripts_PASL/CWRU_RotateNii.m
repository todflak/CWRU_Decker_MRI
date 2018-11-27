%apply the given rotation matrix to the Nii file; can optionally save to a
%new filename (if not supplied, original file will be modified)
% Assume the Q-form is valid, and operates on that; then also copies to the
% S-form

% FORMAT CWRU_ASL_RotateNii(Nii_ToRotate_Filename, qRotation, ... 
%    [Nii_Rotated_Filename])
%  Nii_ToRotate_Filename: filename of Nii to rotate
%  qRotation: a quaterion (of class quaternion MIT Lincoln Laboratory)
%  Nii_Rotated_Filename: name of new Nii file to create; if empty, will
%                    modify the original Nii
%Tod Flak, 31 July 2017

function CWRU_RotateNii(Nii_ToRotate_Filename, qRotation, Nii_Rotated_Filename)
   if isempty(Nii_Rotated_Filename), Nii_Rotated_Filename = Nii_ToRotate_Filename; end;
   
   nii = load_untouch_nii(Nii_ToRotate_Filename);
   
   %load the current Q-form rotation matrix and translation offsets
   [q_original, t_original]= CWRU_Nii_load_rotation(Nii_ToRotate_Filename, 'q-form');
   
   % find the voxel location of the current image 0,0,0 point (based on
   % translation coordinates
   Vox_origin = linsolve(q_original.RotationMatrix, -1* (t_original.'));
   
   q_new = qRotation .* q_original;

   % translate the Vox_origin into new rotation space
   P_origin_spaceB = q_new.RotationMatrix * Vox_origin;
   t_new = -1 * P_origin_spaceB; %take the negative to get the required translation offsets

   % put new info into q-form values
   nii.hdr.hist.quatern_b = q_new.e(2);
   nii.hdr.hist.quatern_c = q_new.e(3);
   nii.hdr.hist.quatern_d = q_new.e(4);
   nii.hdr.hist.qoffset_x = t_new(1);
   nii.hdr.hist.qoffset_y = t_new(2); 
   nii.hdr.hist.qoffset_z = t_new(3);

   %also save into s-form
   pixdim_diag = diag(nii.hdr.dime.pixdim(2:4));  %get the voxel dimensions, and put in a diagonal matrix
   rotmat_scaled = q_new.RotationMatrix * pixdim_diag;      %apply voxel size scaling to the rotation matrix
   rotmat_scaled(:,3) =  rotmat_scaled(:,3) * nii.hdr.dime.pixdim(1);  % apply the +1 or -1 qfac from pixdim(1)
   rotmat_scaled(:,4) = (t_new.');  %transpose the t_new vector to set the fourth column of matrix
   %stick the info back into the s-form params
   nii.hdr.hist.srow_x = rotmat_scaled(1,:);
   nii.hdr.hist.srow_y = rotmat_scaled(2,:);
   nii.hdr.hist.srow_z = rotmat_scaled(3,:);
   
   
   save_untouch_nii(nii, Nii_Rotated_Filename);
end
