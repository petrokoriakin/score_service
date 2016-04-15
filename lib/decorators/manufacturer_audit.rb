class Decorators::ManufacturerAudit < Decorators::Base

  def table_data
    {
      :rows => collection.collect do |a|
        {
          :id => a.id,
          :cell => [
            h(a.kind),
            a.auditor_name,
            h(a.audit_status),
            pretty_date(a.proposed_date),
            pretty_date(a.scheduled_date),
            pretty_date(a.performed_date),
            h(a.audit_score),
            pretty_date(a.car_due_date),
            pretty_date(a.car_approved_date),
            link_to( "View", manufacturer_manufacturer_audit_path(manufacturer, a))
          ]
        }
      end
    }
  end

  def paginated_list
    table_data.merge pagination_data
  end

  def auditor_select_tag
    select_tag 'audit[auditor]', options_for_select(user_selections, model.auditor_id)
  end

  def score_select_tag
    select_tag 'audit[score]', options_for_select(score_options, model.score)
  end

  def score_options
    target_account.manufacturer_audit_scores.all(:conditions => {:active => true}, :order => "score ASC").map do |score|
      [score.score, score.score]
    end
  end

  def target_account
    manufacturer.account
  end

  def prepare_fields!
    @fields = []
    if account.licensee? || (current_status && current_status.active?)
      return if @preview_mode
      fields_for_active_status
    elsif model.email_step?
      if @preview_mode
        fields_for_active_status
        fields << editable_form_area('Comments:', join(sanitize_with_br(model.comment), edit_link), comment_input)
        fields << [textarea_form_tag(last_updated)]
      else
        email_fields
      end
    else
      try(('fields_for_' + current_stage.to_s).to_sym) unless @preview_mode
    end
    fields << [(comment_fields || '')] unless @preview_mode
    fields << [textarea_form_tag(last_updated)] if current_status && current_status.active?
    unless @preview_mode
      fields << [hidden_field_tag("default_attachment_ids", model.attachments.pluck_ids('default').join(','))]
      fields << [hidden_field_tag("corrective_attachment_ids", model.attachments.pluck_ids('corrective').join(','))]
    end
  end

  def comment_fields
    if account.licensee? || !model.email_step?
      if account.licensee? || (current_status && current_status.active?)
        editable_form_area('Comments:', join(sanitize_with_br(model.comment), edit_link), comment_input)
      else
        form_row('Comments:', comment_input, 'textarea')
      end
    end
  end

  def comment_input
    text_area_tag('audit[comments]', model.comment, :size => "48x8", :disabled => account.licensee?)
  end

  def email_fields
    fields << [
      ['To:', text_field_tag('audit[email][to]', model.email.to(model.manufacturer), :size => 41)],
      ['CC:', text_field_tag('audit[email][cc]', model.email.cc(model.manufacturer), :size => 41)],
      ['Subject:', text_area_tag('audit[email][subject]', model.email.subject, :size => '48x8'), 'textarea'],
      ['Body:', text_area_tag('audit[email][body]', model.email.body, :size => "48x8"), 'textarea']
    ].map{ |params| form_row(*params) }
    fields << [hidden_field_tag('audit[email][reply_to]', model.email.reply(model.manufacturer))]
  end

  def fields_for_new
    fields << [
      ['Auditor:', auditor_select_tag],
      ['Audit Type:', text_field_tag('audit[audit_type]', model.kind, :size => 31)],
      ['Proposed Audit Date:', date_form_tag(:audit, :proposed_date, (model.proposed_date || Time.now))]
    ].map{ |params| form_row(*params) }
  end

  def fields_for_requested
    [
      editable_form_row('Auditor:', auditor_contacts, auditor_select_tag),
      editable_form_row('Audit Type:', join(h(kind), edit_link), text_field_tag('audit[audit_type]', model.kind)),
      form_row('Audit Status:', h(audit_status)),
      editable_form_row('Proposed Audit Date:', join(pretty_date(proposed_date), edit_link), date_form_tag(:audit, :proposed_date, (model.proposed_date || Time.now)))
    ]
  end

  def fields_for_schedule_date_selection
    fields << [
      form_row('Scheduled Audit Date:', date_form_tag(:audit, :scheduled_date, (model.scheduled_date || model.proposed_date || Time.now)))
    ]
  end
  alias_method :fields_for_reschedule_date_selection, :fields_for_schedule_date_selection

  def fields_for_scheduled
    unless current_stage == :scheduled
      editable_form_row(
        'Scheduled Audit Date:',
        join(pretty_date(scheduled_date), edit_link),
        date_form_tag(:audit, :scheduled_date, (model.scheduled_date || model.proposed_date || Time.now))
      )
    else
      form_row('Scheduled Audit Date:', pretty_date(scheduled_date))
    end
  end

  def fields_for_performed
    [
      editable_form_row(
        'Audit Performed Date:', 
        join(pretty_date(performed_date), edit_link),
        date_form_tag(:audit, :performed_date, (model.performed_date || model.scheduled_date))
      ),
      editable_form_row('Audit Score:', join(h(audit_score), edit_link), score_select_tag),
      editable_form_area_with_label('Audit Attachments:', audit_attachments_with_link(:default), fields_for_dropzone(:default))
    ]
  end

  def fields_for_car_due
    editable_form_row(
      'Corrective Action<br> Reply Due:',
      join(pretty_date(car_due_date), edit_link),
      date_form_tag(:audit, :car_due_date, model.car_due_date || Time.now)
    )
  end

  def fields_for_car_approved
    [
      editable_form_row(
        'Corrective Action<br> Reply Approved:',
        join(pretty_date(car_approved_date), edit_link),
        date_form_tag(:audit, :car_approved_date, (model.car_approved_date || model.car_due_date))
      ),
      editable_form_area_with_label('Corrective Action<br>Attachments:', audit_attachments_with_link(:corrective), fields_for_dropzone(:corrective))
    ]
  end


  def fields_for_active_status
    fields << fields_for_requested
    fields << [fields_for_scheduled] if model.previous_weight >= (@preview_mode ? 23 : 29)
    fields << fields_for_performed if model.previous_weight >= (@preview_mode ? 33 : 39)
    fields << [fields_for_car_due] if model.previous_weight > (@preview_mode ? 42 : 43)
    fields << fields_for_car_approved if model.previous_weight > 60
  end

  def fields_for_performed_date_selection
    fields << [
      form_row('Audit Performed Date:', date_form_tag(:audit, :performed_date, (model.performed_date || model.scheduled_date))),
      form_row('Audit Score:', score_select_tag),
      editable_form_area_with_label('Audit Attachments:', audit_attachments_with_link(:default, 'upload'), fields_for_dropzone(:default))
    ]
  end

  def js_for_dropzone
    super(model.attachments.default, :default) + super(model.attachments.corrective, :corrective)
  end

  def fields_for_car_due_date_selection
    fields << [
      form_row('Corrective Action Reply Due Date:', date_form_tag(:audit, :car_due_date, model.car_due_date || Time.now))
    ]
  end

  def fields_for_car_approved_date_selection
    fields << [
      form_row('Corrective Action Reply<br>Approved Date:', date_form_tag(:audit, :car_approved_date, (model.car_approved_date || model.car_due_date))),
      editable_form_area_with_label('Corrective Action<br>Attachments:', audit_attachments_with_link(:corrective, 'upload'), fields_for_dropzone(:corrective))
    ]
  end

  def audit_attachments_with_link(type = :default, link_text = 'edit')
    audit_attachments(type) << (edit_link(false, link_text) || '')
  end

  def last_updated
    if model.last_updated_by
      'last updated by ' + last_updated_by + ' on ' + pretty_date(last_updated_at)
    end
  end

  def auditor_contacts
    if auditor_phone
      join(auditor_name, auditor_email) + tag(:br) + join(auditor_phone, edit_link)
    else
      auditor_name + tag(:br) +  join(auditor_email, edit_link)
    end
  end

  def current_status
    model.status || target_account.manufacturer_audit_statuses.detect{|s| s.status.to_sym == current_stage}
  end

  def status_actions
    if current_status
      current_status.next_statuses.map(&:action_name)
    else
      ["Request Audit"]
    end
  end

  def next_steps
    if status_actions.any?
      next_labels = status_actions
      next_labels.reverse! if next_labels == ["Complete Audit", "Request Corrective Action"]
      next_labels.collect do |action|
        submit_tag(action, :name => 'audit[next_stage]', :style => "margin-right: 15px;")
      end.join
    end
  end

  def render_header
    if model.email_step? && !account.licensee?
      content_tag(:h2, "#{h(model.next_stage_name)} Email Notification")
    else
      tag(:br)
    end
  end

  def update_button
    submit_tag('Update', :name => 'audit[update_without_transition]', :id => 'update_without_transition', :style => "float: right; display: none;")
  end

  def back_link
    link = if current_stage == :new
      link_to('Back',manufacturer_path(model.manufacturer, {:anchor => "audits"}))
    elsif current_status && !current_status.active?
      link_to('Back', manufacturer_manufacturer_audit_path(model.manufacturer.id, model.id, :next_stage => 'previous_status'), :method => :put)
    else
      ''
    end
    tag(:br) + tag(:br) + link
  end

  def prepare_fields_preview_mode
    @preview_mode = true
    prepare_fields!
  end

  def render_form_fields(preview_mode = false)
    if preview_mode
      prepare_fields_preview_mode
    else
      prepare_fields!
    end
    result = hidden_field_tag 'audit[current_stage]', model.current_stage
    result += content_tag "table", :class => "display", :border => "0", :cellpadding => "0", :cellspacing => "0", :style => 'text-align: left;' do
      fields.join
    end if fields.any?
    if !account.licensee? && !@preview_mode
      result += tag(:br) + (next_steps || '')
      result += update_button unless ['performed_date_selection', 'car_approved_date_selection'].include?(model.current_stage)
      result += back_link
    end
    result << debug(model.current_stage) if debug?
    result << debug(model.previous_weight) if debug?
    result
  end

  def current_stage
    params.fetch(:stage, model.current_stage).to_sym
  end

  private

  def debug?
    Rails.env.development? || Rails.env.feature_test5?
  end

  def editing?
    params[:stage].present?
  end

  def audit_attachments(type = :default)
    model.attachments.send(type).inject('') do |acc, attachment|
      acc << ' '
      acc << link_to(
        attachment.user_attachment.file_file_name,
        attachment.user_attachment.file.url,
        :class => "attachment-#{attachment.user_attachment_id}"
        )
      acc << tag(:br)
    end
  end

  def join(*args)
    args.reject(&:blank?).join(' | ')
  end

end
