class AllowNullPostcardTemplateInCreatives < ActiveRecord::Migration[8.0]
  def change
    change_column_null :creatives, :postcard_template_id, true
  end
end

