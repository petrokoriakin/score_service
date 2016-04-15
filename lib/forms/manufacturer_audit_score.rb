class Forms::ManufacturerAuditScore < Forms::Base

  def initialize(model = nil, params = nil, account = nil, collection = [])
    super
    assign_attributes
    build_email
  end

  def assign_attributes
    model.score = params[:score]
    model.active = true
  end

  def persist!
    model.save!
  end

end
