class AdminCustom::SettingsController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def edit
    @whatsapp_number = CroSetting.get('whatsapp_number', '')
    @landing_page_banner = CroSetting.get('landing_page_banner', '')
    @meta_pixel_id = CroSetting.get('meta_pixel_id', '')
    @google_analytics_id = CroSetting.get('google_analytics_id', '')
    @google_tag_id = CroSetting.get('google_tag_id', 'GT-55KXGQZ')
    @gtm_container_id = CroSetting.get('gtm_container_id', 'GTM-N28R82Z')
    @google_ads_conversion_id = CroSetting.get('google_ads_conversion_id', '')
    @google_ads_conversion_label = CroSetting.get('google_ads_conversion_label', '')
  end

  def update
    CroSetting.set('whatsapp_number', params[:whatsapp_number])
    CroSetting.set('landing_page_banner', params[:landing_page_banner])
    CroSetting.set('meta_pixel_id', params[:meta_pixel_id])
    CroSetting.set('google_analytics_id', params[:google_analytics_id])
    CroSetting.set('google_tag_id', params[:google_tag_id])
    CroSetting.set('gtm_container_id', params[:gtm_container_id])
    CroSetting.set('google_ads_conversion_id', params[:google_ads_conversion_id])
    CroSetting.set('google_ads_conversion_label', params[:google_ads_conversion_label])
    
    redirect_to edit_admin_custom_settings_path, notice: "CRO Settings updated successfully."
  end
end
