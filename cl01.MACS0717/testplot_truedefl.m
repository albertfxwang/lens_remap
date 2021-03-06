% test if the corrected deflection angle maps present indeed a much better results

clear all; clc; tic

addpath ../mscripts/
PlotParams;

sys= '14';
imgID=  {'14.1'; '14.2'; '14.3' };
num_img=length(imgID);

pic_name=[sys '.tot_src_truedefl.ps'];
truedefl_dir= 'CorrDefl_imgF140W_z1.855_sharon';      % the folder containing *_truedefl.dat files
truedefl_root='_truedefl.dat';
% diary(fullfile(truedefl_dir,[sys,'.tot_src_truedefl.diary']));
imgstamp_dir= 'imgF140W_z1.855peak_fullfits';
ra_root=    '_ra.dat';
dec_root=   '_dec.dat';
img_root=   '_cut.dat';
SLcatalog = importdata('z1.855_SLimgPeak.cat', ' ', 2);
img_coord = SLcatalog.data;
img_ctr=    zeros(num_img,2);   % 1st column: RA. 2nd column: DEC.
src_ctr=    zeros(num_img,2);

%------------ HST image's reference pixel's WCS coord
%$ imhead MACS0717_F814WF105WF140W_R.fits | grep CRVAL1 (->RA), CRVAL2 (->DEC)
ref_ra= 109.384564525;
ref_dec=37.7496681474;

%------------ set the handle for plotting
h=figure(1);
clf
hold on

for i=1:num_img
    %------------ searching for img_ctr for imgID{i} in SLcatalog
    indx_img=     find(abs(img_coord(:,1) - str2double(imgID{i}))<1e-6);
    img_ctr(i,:)= img_coord(indx_img,2:3);
    %------------ read-in img counts, RA/DEC for postage stamps
    img_all=    load(fullfile(imgstamp_dir,[imgID{i} img_root]));
    img_ra_all= load(fullfile(imgstamp_dir,[imgID{i} ra_root]));
    img_dec_all=load(fullfile(imgstamp_dir,[imgID{i} dec_root]));
    %------------ read-in corrected deflection angle maps
    alpha_all=  importdata(fullfile(truedefl_dir,[imgID{i} truedefl_root]), ' ', 5);
    alpha1_all= alpha_all.data(:,1);
    alpha2_all= alpha_all.data(:,2);
    indx_alpha1=find(~isnan(alpha1_all));
    indx_alpha2=find(~isnan(alpha2_all));
    %------------ check if alpha1,2 have exactly the same form
    if numel(indx_alpha1)~=numel(indx_alpha2)
        fprintf('ERR: the dims of indx_alpha1 and indx_alpha2 don''t match!\n')
    elseif max(abs(indx_alpha1-indx_alpha2)) > 1e-3
        fprintf('ERR: some misalignments in indx_alpha1,2 exist!\n')
    else
        indx_all=indx_alpha1;
    end
    %------------ select the common part of img,ra,dec,alpha1,2 vectors (avoid the NaN problems)
    alpha1= alpha1_all(indx_all);
    alpha2= alpha2_all(indx_all);
    img=    img_all(indx_all);
    img_ra= img_ra_all(indx_all);
    img_dec=img_dec_all(indx_all);
    %------------ interpolate alpha1,2_ctr for img_ctr
    alpha1_ctr=griddata(img_ra,img_dec,alpha1,img_ctr(i,1),img_ctr(i,2));
    alpha2_ctr=griddata(img_ra,img_dec,alpha2,img_ctr(i,1),img_ctr(i,2));
    %------------ use "DeflBack2src" to remap to src plane
    [src_ra,src_dec]=DeflBack2src(img_ra,img_dec,alpha1,alpha2,ref_dec);
    [src_ctr(i,1),src_ctr(i,2)]=DeflBack2src(img_ctr(i,1),img_ctr(i,2),alpha1_ctr,alpha2_ctr,ref_dec);
    %------------ convert (RA,DEC) to (da,db) w.r.t. the reference pixel
    [src_da,src_db]=wcs2darcsec(src_ra,src_dec,[ref_ra ref_dec]);
    [srctr_da,srctr_db]=wcs2darcsec(src_ctr(i,1),src_ctr(i,2),[ref_ra ref_dec]);
    %------------ plotting
    scatter(src_da,src_db,3,img)
    plot(srctr_da,srctr_db,'ko','MarkerSize',marker_size,'LineWidth',lw2)
%     clear img_all img_ra_all img_dec_all alpha_all alpha1_all alpha2_all
end
colormap('jet');
hold off
xlabel('da [arcsec]','FontSize',lab_fontsize);
ylabel('db [arcsec]','FontSize',lab_fontsize);
title(['MACS0717 total sys ',sys,' on src plane (corrected alpha)'])
set(gca,'FontSize',axes_fontsize,'LineWidth',lw_gca,'XDir','Reverse'); 
ax = gca;
hbar = colorbar('EastOutside');
axes(hbar);
% ylabel('Counts','FontSize',lab_fontsize);     in unit of surface brightness, not counts 
set(gca,'FontSize',axes_fontsize);
axes(ax);
axis([-Inf,Inf,-Inf,Inf]);

%% end-up work for the figure
set(gcf, 'PaperUnits','inches');
set(gcf, 'PaperPosition',[ 0 0 8 6]);
print(h,'-dpsc2',fullfile(truedefl_dir,pic_name));
toc
% diary off
