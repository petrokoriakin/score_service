class Forms::Base

  attr_accessor :model, :params, :current_user, :collection

  def initialize(model = nil, params = nil, current_user = nil, collection = [])
    @model = model
    @params = params
    @current_user = current_user
    @collection = collection
  end

  def self.human_name
    'Some FormObject'
  end

  def persisted?
    false
  end

  def new_record?
    false
  end

  def save
    return false unless self.valid?
    persist!
  end

  def save!
    save or raise ActiveRecord::RecordInvalid
  end

  def build_email
    unless model.email_template
      model.email_template = Notification::Email.create(
        :body => params[:body],
        :subject => params[:subject]
      )
    end
    model.email_template.parse_recipients(params[:email])
  end

  include ::ActiveRecord::Validations

  def method_missing(method_sym, *arguments, &block)
    model.try(method_sym, *arguments, &block)
  end

  def underscorize(opt)
    opt.camelize.gsub(' ', '').underscore
  end

  def symbolize(*opts)
    opts.map{|opt| underscorize opt }.join('_').to_sym
  end

private

  def persist!
    true
  end

end
