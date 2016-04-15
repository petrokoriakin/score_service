class Decorators::Base

  include DateFormatHelper
  include ActionView::Helpers

  attr_accessor :output_buffer, :fields
  attr_accessor :model, :params, :account, :collection

  ACCOUNT_ROLES = [["Account Manager", -10], ["Creative Contact", -12], ["Financial Contact", -11], ['Quality Contact', -31]]
  LICENSEE_ROLES = [['Licensee Business Contact',-1],  ['Licensee Creative Contact',-3],   ['Licensee Financial Contact',-2], ['Licensee Quality Contact', -30]]
  MANUFACTURER_ROLES = [['Manufacturer Key Contact', -41]]

  def initialize model = nil, params = nil, account = nil, collection = []
    @model = model
    @params = params
    @account = account
    @collection = collection
    @fields = []
    @preview_mode = false
  end

  def protect_against_forgery?
    false
  end

  def role_and_user_select_options
    role_selections + [['------------------',-100]] + user_selections
  end

  def user_selections
    target_account.users.all(:order => 'contact_last_name, contact_first_name ASC').collect{|u| [u.full_name,u.id]}
  end

  def role_selections
    ACCOUNT_ROLES
  end

  def pagination_data
    page = params[:page].to_i || 1
    record_count = collection.length
    page_total = record_count / params[:rows].to_i + (record_count % params[:rows].to_i == 0 ?  0 : 1)
    {:page => page, :total => page_total, :records => record_count}
  end

  def form_field content
    content_tag(:p) do
      content
    end
  end

  def recipient_options
    ACCOUNT_ROLES + LICENSEE_ROLES + MANUFACTURER_ROLES + user_selections
  end

  def recipient_multiselect name
    content_tag(:p) do
      "#{name}:" +
      tag(:br) +
      recipient_options.map do |opt|
        recipient_field(name, opt[0], opt[1], recipient_include?(name, opt[1])) + tag(:br)
      end.join
    end
  end

  def recipient_include? kind, id
    model.email_template.send("#{kind.downcase}_recipient_ids".to_sym).include?(id)
  end

  def recipient_field kind, name, id, checked = false
    content_tag(:label, :class => "li") do
      check_box_tag("email[#{kind.downcase}_recipient_ids][]", id, checked) +
      content_tag(:u) do
        name
      end
    end
  end

  def email_fields
    model.create_email_template unless model.email_template
    [
      form_field(label_tag('email[reply_to_recipient_id]', "Email reply-to:") + select_tag('email[reply_to_recipient_id]', options_for_select(role_and_user_select_options, model.email_template.reply_to_recipient_id))),
      recipient_multiselect('To'),
      recipient_multiselect('CC'),
      form_field(label_tag('email[subject]', "Subject:") + tag(:br) + text_area_tag('email[subject]', model.email_template.subject, :size => "40x5")),
      form_field(label_tag('email[body]', "Body:") + tag(:br) + text_area_tag('email[body]',  model.email_template.body, :size => "40x5")),
    ]
  end

  def form_row(label, content, type = 'string')
    if type == 'textarea'
      textarea_form_tag(label) + textarea_form_tag(content)
    else
      content_tag(:tr) do
        content_tag(:td, label) + content_tag(:td, content)
      end
    end
  end

  def editable_form_row(label, visible_content, hidden_content)
    css_class = "editable-#{rand(1000)}"
    content_tag(:tr, :class => css_class) { content_tag(:td, label) + content_tag(:td, visible_content) } +
    content_tag(:tr, :class => css_class, :style => 'display: none;') { content_tag(:td, label) + content_tag(:td, hidden_content) }
  end

  def editable_form_area(label, visible_content, hidden_content)
    css_class = "editable-#{rand(1000)}"
    content_tag(:tr, :class => css_class) { content_tag(:td, label) + content_tag(:td, visible_content) } +
    textarea_form_tag(label, css_class, 'display: none;') + textarea_form_tag(hidden_content, css_class, 'display: none;')
  end

  def editable_form_area_with_label(label, visible_content, hidden_content)
    css_class = "editable-#{rand(1000)}"
    content_tag(:tr, :class => css_class) { content_tag(:td, label) + content_tag(:td, visible_content) } +
    textarea_form_tag(hidden_content, css_class, 'display: none;')
  end

  def textarea_form_tag(content = '', css_class = '', style = '')
    content_tag(:tr, :class => css_class, :style => style) do
      content_tag(:td, :colspan => '2') { content }
    end
  end

  def sanitize_with_br(str = '')
    (str || "").split("\n").map{|s| h(s)}.join(tag(:br))
  end

  def date_form_tag object, name, value
    date_select object, name, :start_year => Date.current.year - 10, :end_year => Date.current.year + 5, :default => value
  end

  def render_table
    content_tag :table, :class => "display", :border => "0", :cellpadding => "0", :cellspacing => "0" do 
      table_header + table_contents
    end
  end

  def id
    if model.kind_of?(ActiveRecord::Base)
      model.id
    else
      model.model.id
    end
  end

  def edit_link(toggle_label = true, text = 'edit')
    if !account.licensee? && !@preview_mode
      css_class = toggle_label ? 'editable_row' : 'toggleable_row'
      link_to(text, '#', :class => css_class)
    end || ''
  end

  def error_messages
    model.errors.map{ |err| err[1] }.join("<br>")
  end

  def js_for_editable
    <<-js
      jQuery(document).on('click', '.editable_row', function(e) {
        e.preventDefault();
        jQuery('.'+ jQuery(this).parents('tr').attr('class')).show();
        jQuery(this).parents('tr').hide();
        jQuery('#update_without_transition').show();
      });
      jQuery(document).on('click', '.toggleable_row', function(e) {
        e.preventDefault();
        jQuery('.'+ jQuery(this).parents('tr').attr('class')).show();
        jQuery('#update_without_transition').show();
      });
    js
  end

  def fields_for_dropzone(type = nil)
    target = type ? type.to_s+'_' : ''
    content_tag(:div, :id => "upload_#{target}attachment", :class =>'dz', :style => 'width:405px;') do
      content_tag(:div, :class =>'dz-message') do
        'Drag and drop files to this space, or click here to select files.' +
        tag(:br) +
        'You can upload multiple files at once!'
      end
    end
  end

  def js_for_dropzone(attachments = [], type = nil)
    target = type ? type.to_s+'_' : ''
    <<-js
      var set_#{target}attachment_ids = function(dz, delete_id) {
        values = jQuery.map(dz.files, function(item) { return item.attachment_id; });

        current_values = jQuery('##{target}attachment_ids').val();
        current_values = current_values == '' ? [] : current_values.split(',');
        current_values = jQuery.map(current_values, function(item) { return parseInt(item) });

        if (delete_id) {
          current_values = jQuery.grep(current_values, function(value) {
            return value != delete_id;
          });
          jQuery('.attachment-'+delete_id).hide();
        }
        values = jQuery.unique(jQuery.merge(values, current_values));
        jQuery('##{target}attachment_ids').val(values.join(','));
      }

      jQuery('#upload_#{target}attachment').dropzone({
        url: '#{ user_attachments_path }',
        addRemoveLinks: true,
        maxFileSize: 1024,
        init: function() {
          this.on('removedfile', function(file) {
            set_#{target}attachment_ids(this, file.attachment_id);
          });

          this.on('success', function(file, data) {
            file.attachment_id = data.id;
            set_#{target}attachment_ids(this);
          });

          this.on('sending', function(file, xhr, data) {
            data.append('klass', '#{ManufacturerAuditAttachment}');
          });

          #{dz_attachments(attachments)}
        }
      });
    js
  end

  def dz_attachments(attachments)
    attachments.collect do |a|
      "file = { name: '#{ escape_javascript(a.user_attachment.file.original_filename) }', size: '#{a.user_attachment.file.size}', attachment_id: '#{a.user_attachment_id}' };" +
      "this.emit('addedfile', file);" +
      "this.emit('complete', file);"
    end.join
  end

  def method_missing(method_sym, *arguments, &block)
    model.send(method_sym, *arguments, &block)
  end

end
