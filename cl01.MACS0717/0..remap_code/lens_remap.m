% calculate source plane grids 

clear all; clc; tic
diary('4.1_remap.diary');
fprintf('---------------------------------------------------\n')
fprintf('|       MACS0717   -   4.1_remap                 |\n')
fprintf('|       Lens Model: z1.855_zitrin_ltm-gauss/      |\n')
fprintf('|       Observed HST image: imgF140W/             |\n')
fprintf('---------------------------------------------------\n')

%% load in data
img_id= '4.1_';
SLcatalog = importdata('z1.855_SLimg.cat', ' ', 2);
img_coord = SLcatalog.data;
indx=find(abs(img_coord(:,1) - str2num(img_id(1:end-1)))<1e-6);
img_ctr = img_coord(indx,2:3);

img     =load('imgF140W/4.1_cut.dat');
img_ra  =load('imgF140W/4.1_ra.dat');      % here image RA/DEC is NOT axis values
img_dec =load('imgF140W/4.1_dec.dat');     % you should interp to get value at each pair of them

alpha1  =load('z1.855_zitrin_ltm-gauss/4.1_alpha1.dat');
alpha2  =load('z1.855_zitrin_ltm-gauss/4.1_alpha2.dat');
kappa   =load('z1.855_zitrin_ltm-gauss/4.1_kappa.dat');
gamma1  =load('z1.855_zitrin_ltm-gauss/4.1_gamma1.dat');
gamma2  =load('z1.855_zitrin_ltm-gauss/4.1_gamma2.dat');
mag     =load('z1.855_zitrin_ltm-gauss/4.1_mag.dat');
lens_ra =load('z1.855_zitrin_ltm-gauss/4.1_lensra.dat');    % lens RA/DEC can be treated as axis values
lens_dec=load('z1.855_zitrin_ltm-gauss/4.1_lensdec.dat');   % since there's a good alignment btw WCS coord and its axes

N_img=length(img_ra);
if length(img_dec)~= N_img
    fprintf('dimensions of image''s RA DEC don''t get along!\n')
    break
else
    fprintf('length of the image = %d, square size=%d\n',N_img,sqrt(N_img))
end

%------------ the rotation-mat
CD1_1   =   2.88458365395E-06;      % Degrees / Pixel                                
CD2_1   =   -1.35860373808E-05;     % Degrees / Pixel                                
CD1_2   =   -1.35860367285E-05;     % Degrees / Pixel                                
CD2_2   =   -2.88458536178E-06;     % Degrees / Pixel                                
CD=[CD1_1 CD1_2; CD2_1 CD2_2];

%------------ HST image's reference pixel's WCS coord
%$ imhead MACS0717_F814WF105WF140W_R.fits | grep CRVAL1 (->RA), CRVAL2 (->DEC)
ref_ra=109.384564525;
ref_dec=37.7496681474;

%------------ the parameter controling how far away the corners to the
%center of each pixel, similar to "pixelfrac", at the range of [0, 0.5]
q=0.5;
dpixel4=[q q -q -q; q -q -q q]; % corners in upper-right, lower-right, lower-left, upper-left (clockwise)

alpha1_img=zeros(N_img,1);
alpha2_img=zeros(N_img,1);
kappa_img=zeros(N_img,1);
gamma1_img=zeros(N_img,1);
gamma2_img=zeros(N_img,1);
mag_img=zeros(N_img,1);

dRA4_img=zeros(N_img,4);
dDEC4_img=zeros(N_img,4);
dRA4_src=zeros(N_img,4);
dDEC4_src=zeros(N_img,4);
RA4_src=zeros(N_img,4);
DEC4_src=zeros(N_img,4);
sb_src=zeros(N_img,4);

%% 2D interpolation to evaluate alpha, Jacobian-mat at each pixel's center
for j=1:N_img
    alpha1_img(j)=interp2(lens_ra,lens_dec,alpha1,img_ra(j),img_dec(j));   % default method: linear
    alpha2_img(j)=interp2(lens_ra,lens_dec,alpha2,img_ra(j),img_dec(j));
    gamma1_img(j)=interp2(lens_ra,lens_dec,gamma1,img_ra(j),img_dec(j));
    gamma2_img(j)=interp2(lens_ra,lens_dec,gamma2,img_ra(j),img_dec(j));
    kappa_img(j)=interp2(lens_ra,lens_dec,kappa,img_ra(j),img_dec(j));
    mag_img(j)=interp2(lens_ra,lens_dec,mag,img_ra(j),img_dec(j));
    fprintf('finished No.%d interpolation set!\n',j)
end
alpha1_ctr=interp2(lens_ra,lens_dec,alpha1,img_ctr(1),img_ctr(2));
alpha2_ctr=interp2(lens_ra,lens_dec,alpha2,img_ctr(1),img_ctr(2));
mag_ctr=interp2(lens_ra,lens_dec,mag,img_ctr(1),img_ctr(2));   % interp for the image center

% compute the elements of the Jacobian-mat
jacob_11 = 1 - kappa_img - gamma1_img;
jacob_22 = 1 - kappa_img + gamma1_img;
jacob_12 = -gamma2_img;
jacob_21 = jacob_12;

%% Step 1: apply the deflection angle shift to the center of each pixel
%          so now we need to specify two matrices of the same dimension to
%          the img matrix, to record the RA, DEC for each grid cell
RA0_src=img_ra+alpha1_img/60./cos(ref_dec/180.*pi);       % Remember the RA-axis is inverted, AND  the cos-factor !!!
DEC0_src=img_dec-alpha2_img/60.;
ctr_ra=img_ctr(1)+alpha1_ctr/60./cos(ref_dec/180.*pi);
ctr_dec=img_ctr(2)-alpha2_ctr/60.;

%% Step 2: apply Jacobian-mat to 4 corner points of each pixel
%          but even before that, you have to calc (RA,DEC) of them at
%          image's plane using the rotation-mat
for i=1:N_img
    fprintf('\n---No.%d pixel--- img_ctr(%10.8e,%10.8e) => src_ctr(%10.8e,%10.8e)\n',...
        i,img_ra(i),img_dec(i),RA0_src(i),DEC0_src(i))
        for t=1:4
            temp_img=CD*dpixel4(:,t);                   % temp_img: [dalpha; dbeta]
            dRA4_img(i,t)=temp_img(1)/cos(ref_dec/180*pi);
            dDEC4_img(i,t)=temp_img(2);
            temp_src=[jacob_11(i) jacob_12(i); jacob_21(i) jacob_22(i)]...
                *[dRA4_img(i,t); dDEC4_img(i,t)];       % temp_src: [dRA4_src; dDEC4_src]
            dRA4_src(i,t)=temp_src(1);
            dDEC4_src(i,t)=temp_src(2);
            RA4_src(i,t)=RA0_src(i)+dRA4_src(i,t);
%<<<140701>>> here adding dRA like this is wrong!
            DEC4_src(i,t)=DEC0_src(i)+dDEC4_src(i,t);
%            counts_src(i,t)=0.25*img(i);
            sb_src(i,t)=img(i);
            % It's the concept of conservation of surface brightness rather than photon counts
            % actually there should also be an extra consts as well as taking log but dropped here for convenience
            fprintf('(%d, %d) img(%10.8e,%10.8e) => src(%10.8e,%10.8e)\n',...
                i,t,dRA4_img(i,t)+img_ra(i),dDEC4_img(i,t)+img_dec(i),RA4_src(i,t),DEC4_src(i,t))
            clear temp_img temp_src
        end
end

save 4.1_remap.mat
toc
diary off

