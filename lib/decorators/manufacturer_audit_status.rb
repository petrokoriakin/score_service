class Decorators::ManufacturerAuditStatus < Decorators::Base

  def target_account
    account
  end

  def table_header
    content_tag :tr do
      content_tag(:th, 'Option') +
      content_tag(:th, 'Actions')
    end
  end

  def action_links status
    link_to('Edit', edit_audit_status_templates_path(status)) unless status.status == 'unaudited'
  end

  def table_contents
    collection.map do |status|
      if status.active
        content_tag :tr do
          [
           content_tag(:td, h(status.name)),
           content_tag(:td, action_links(status))
          ].join
        end
      end
    end.join
  end

  def render_form_fields
    fields << content_tag(:p) do
      label_tag(:name, "Status Name:") + text_field_tag(:name, model.name)
    end
    fields << "When this Status is selected, the default email settings are:"
    fields << email_fields
    fields.join
  end

end
