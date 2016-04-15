class Decorators::ManufacturerAuditScore < Decorators::Base
  
  def target_account
    account
  end

  def table_header
    content_tag :tr do
      content_tag(:th, 'Option') +
      content_tag(:th, 'Status') +
      content_tag(:th, 'Actions')
    end
  end

  def score_state active
    active ? 'Active' : 'Retired'
  end

  def action_links score
    if score.active
      link_to('Edit', edit_audit_score_templates_path(score)) + 
      ' | ' + 
      link_to('Retire', retire_audit_score_templates_path(score))
    else
      ''
    end
  end

  def table_contents
    collection.map do |score|
      content_tag :tr do
        [
         content_tag(:td, h(score.score)),
         content_tag(:td, score_state(score.active)),
         content_tag(:td, action_links(score))
        ].join
      end
    end.join
  end

  def render_form_fields
    fields << form_field(label_tag(:score, "Score Option:") + text_field_tag(:score, model.score))
    fields << form_field('When this score is selected, the default email settings are:')
    fields << email_fields
    fields.join
  end

end
