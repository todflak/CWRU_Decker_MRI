function nii = CWRU_nii_MatchSize(niiSource, niiTarget_Header)
	s_org = niiSource.hdr.hist.originator(1:3);
	s_dim = niiSource.hdr.dime.dim(2:4);
	t_org = niiTarget_Header.hist.originator(1:3);  %these origin numbers are in voxel space, not physical mm space
	t_dim = niiTarget_Header.dime.dim(2:4);

	%implement an inline IIF function.  Found at: http://blogs.mathworks.com/loren/2013/01/10/introduction-to-functional-programming-with-anonymous-functions-part-1/
	iif  = @(varargin) varargin{2*find([varargin{1:2:end}], 1, 'first')}();

	%do padding/clipping as necessary.  For each dimension, see if the new image needs to be padded or clipped in that dimension
	%this code altered from code in the FAQ for NIfTI Tools, in "Image overlay related question"
	delta_L = t_org(1)-s_org(1);
	optPad.pad_from_L = iif(delta_L>0, delta_L, true,0);
	optClp.cut_from_L = iif(delta_L<0, -delta_L, true,0);

	delta_R = (t_dim(1)-t_org(1))-(s_dim(1)-s_org(1));
	optPad.pad_from_R = iif(delta_R>0, delta_R, true,0) ;
	optClp.cut_from_R = iif(delta_R<0, -delta_R, true,0);

	delta_P = t_org(2)-s_org(2);
	optPad.pad_from_P =  iif(delta_P>0, delta_P, true,0) ;
	optClp.cut_from_P =  iif(delta_P<0, -delta_P, true,0) ;

	delta_A = (t_dim(2)-t_org(2))-(s_dim(2)-s_org(2));
	optPad.pad_from_A =  iif(delta_A>0, delta_A, true,0) ;
	optClp.cut_from_A =  iif(delta_A<0, -delta_A, true,0) ;

	delta_I = t_org(3)-s_org(3);
	optPad.pad_from_I =  iif(delta_I>0, delta_I, true,0) ;
	optClp.cut_from_I =  iif(delta_I<0, -delta_I, true,0) ;


	delta_S = (t_dim(3)-t_org(3))-(s_dim(3)-s_org(3));
	optPad.pad_from_S =  iif(delta_S>0, delta_S, true,0) ;
	optClp.cut_from_S =  iif(delta_S<0, -delta_S, true,0) ;

	b2 = pad_nii(niiSource,optPad);
	nii = clip_nii(b2,optClp);

	return;
	