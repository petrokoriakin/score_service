class Forms::ManufacturerAudit < Forms::Base

  DATES = %w(proposed scheduled performed car_due car_approved)

  validates_presence_of :kind, :message => "Audit Type can't be blank."
  validates_presence_of :auditor_id, :message => "Auditor can't be blank. There is no agreements with role selected."
  validate :date_params
  validate :email_params

  def initialize(model = nil, params = nil, current_user = nil, collection = [])
    super
    perform_transition
  end

  def self.self_and_descendants_from_active_record
    [ManufacturerAudit]
  end

  def self.human_attribute_name(attribute_key_name, options = {})
    {
      :kind => "Audit Type",
      :auditor => "Auditor"
    }.with_indifferent_access[attribute_key_name]
  end

  def email_params
    if params[:audit] && params[:audit][:email]
      self.errors.add(:email, "To can't be blank") if params[:audit][:email][:to].blank?
      self.errors.add(:email, "CC is invalid") unless valid_email_string?(params[:audit][:email][:cc])
      self.errors.add(:email, "To is invalid") unless valid_email_string?(params[:audit][:email][:to])
      self.errors.add(:email, "Subject can't be blank") if params[:audit][:email][:subject].blank?
      self.errors.add(:email, "Body can't be blank") if params[:audit][:email][:body].blank?
    end
  end

  def date_params
    DATES.each do |date|
      if params[:audit] && params[:audit]["#{date}_date(1i)"] && !parse_and_validate_date(date, params[:audit])
        self.errors.add(:date, "#{date.gsub('_',' ').capitalize} date is invalid")
      end
    end
  end

  def validate_email_and_send
    if self.valid?
      SystemMailer.deliver_simple_with_cc_and_reply_to(params[:audit][:email][:to], 'notification@royaltyzone.com', params[:audit][:email][:cc], params[:audit][:email][:reply_to], params[:audit][:email][:subject], params[:audit][:email][:body])
    end
  end

  def valid_email_string?(str)
    str.split(',').each do |s|
      return false unless valid_email?(s)
    end
    true
  end

  def valid_email?(str)
    str.strip.match(/\A#{Manufacturer::EMAIL_NAME_REGEX}@#{Manufacturer::DOMAIN_HEAD_REGEX}#{Manufacturer::DOMAIN_TLD_REGEX}\z/i)
  end

  def parse_and_validate_date(kind, hash)
    keys = (1..3).map{|i| "#{kind}_date(#{i}i)"}
    Date.new(hash[keys[0]].to_i, hash[keys[1]].to_i, hash[keys[2]].to_i)
  rescue ArgumentError
    nil
  end

  def perform_transition
    touch
    unless return_to_previous?
      general_update
      model.comment = params[:audit][:comments] unless sending_email?
      validate_email_and_send if sending_email?
    else
      model.return_to_previous_status!
    end
  end

  def current_status
    model.available_statuses.detect{|s| s.status == params[:audit][:current_stage]} || model.default_status
  end

  def update_status!(next_stage)
    next_status = current_status.next_statuses.detect{ |s| s.action_name == next_stage }  || model.default_status
    model.create_status_from_template!(next_status, params[:audit][:email])
  end

  def touch
    model.last_updated_by = current_user.full_name
    model.last_updated_at = Time.zone.now
  end

  def activate_audit!
    model.manufacturer.audits.each{|a| a.update_attribute(:latest, (model.id == a.id))}
  end

  def general_update
    passed = lambda { |key| params[:audit].has_key?(key) }

    touch
    assign_auditor if passed[:auditor]

    model.kind    = params[:audit][:audit_type] if passed[:audit_type]
    model.score   = params[:audit][:score] if passed[:score]
    model.manufacturer_audit_score = selected_score  if passed[:score]

    model.proposed_date     = parse_and_validate_date('proposed', params[:audit]) if passed[:proposed_date] || passed['proposed_date(1i)']
    model.scheduled_date    = parse_and_validate_date('scheduled', params[:audit]) if passed[:scheduled_date] || passed['scheduled_date(1i)']
    model.performed_date    = parse_and_validate_date('performed', params[:audit]) if passed[:performed_date] || passed['performed_date(1i)']
    model.car_due_date      = parse_and_validate_date('car_due', params[:audit]) if passed[:car_due_date] || passed['car_due_date(1i)']
    model.car_approved_date = parse_and_validate_date('car_approved', params[:audit])  if passed[:car_approved_date] || passed['car_approved_date(1i)']

    save_attachments if update_attachments?
  end

  def selected_score
    model.manufacturer.account.manufacturer_audit_scores.detect{|s| s.score == params[:audit][:score]}
  end

  def assign_auditor
    contracts = model.manufacturer.contracts
    auditor = if user = User.find_by_id(params[:audit][:auditor])
      user
    else
      case params[:audit][:auditor].to_i
      when -11
        contracts.map{ |c| c.licensor_financial_contact}.first
      when -12
        contracts.map{ |c| c.licensor_creative_contact}.first
      when -31
        contracts.map{ |c| c.licensor_quality_contact}.first
      when -10
        contracts.map{ |c| c.account_manager}.first
      else
        contracts.map{ |c| c.account_manager}.first
      end
    end
    if auditor
      model.auditor = auditor
      model.auditor_name = auditor.full_name
      model.auditor_email = auditor.email
      model.auditor_phone = auditor.phone
    end
  end

  def save_attachments
    model.attachments.delete_all
    create_attachment_type = Proc.new do |type|
      Proc.new do |item|
        model.attachments.create(:type => type, :user_attachment_id => item)
      end
    end
    (params[:default_attachment_ids] || '').split(',').uniq.each(&create_attachment_type['default'])
    (params[:corrective_attachment_ids] || '').split(',').uniq.each(&create_attachment_type['corrective'])
  end

  def persist!
    model.save
    activate_audit!
    update_status!(params[:audit][:next_stage]) if update_status?
    model.save!
  end

  private

  def sending_email?
    params[:audit][:next_stage] == 'Send Email'
  end

  def update_status?
    !return_to_previous? && self.valid? && !editing?
  end

  def update_attachments?
    params[:default_attachment_ids] || params[:corrective_attachment_ids]
  end

  def return_to_previous?
    params[:next_stage] == "previous_status"
  end

  def editing?
    params[:audit][:editing] || params[:audit][:update_without_transition]
  end

end
