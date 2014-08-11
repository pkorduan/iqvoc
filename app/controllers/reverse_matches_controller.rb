class ReverseMatchesController < ApplicationController
  before_action :prepare_match, only: [:add_match, :remove_match]

  def add_match
    begin
      @unpublished_concept ||= @published_concept.branch(@botuser)
      @unpublished_concept.save
      @target_match_class.constantize.create( concept_id: @unpublished_concept.id, value: @uri )
    rescue
      render_response :server_error and return
    ensure
      @unpublished_concept.unlock
      @unpublished_concept.save
    end

    render_response :mapping_added
  end

  def remove_match
    begin
      @unpublished_concept ||= @published_concept.branch(@botuser)
      @unpublished_concept.save
      match = @target_match_class.constantize.find_by( concept_id: @unpublished_concept.id, value: @uri )
      render_response :unknown_relation and return if match.nil?
      match.destroy
    rescue
      render_response :server_error and return
    ensure
      @unpublished_concept.unlock
      @unpublished_concept.save
    end

    render_response :mapping_removed
  end

  protected

  def prepare_match
    begin
      origin = params.require(:origin)
      @uri = params.require(:uri)
      match_class = params.require(:match_class)
    rescue
      render_response :parameter_missing and return
    end

    match_classes = Iqvoc::Concept.reverse_match_class_names
    render_response :unknown_match and return if match_classes.values.exclude? match_class
    klass = match_classes.key(match_class)
    @target_match_class = klass.constantize.reverse_match_class_name
    render_response :unknown_match and return if @target_match_class.nil?

    iqvoc_sources = Iqvoc.config['sources.iqvoc']
    render_response :no_referer and return if request.referer.nil?
    referer = URI.parse(request.referer)
    iqvoc_sources.map!{ |s| URI.parse(s) }
    render_response :unknown_referer and return if iqvoc_sources.exclude? referer

    concept = Iqvoc::Concept.base_class.find_by(origin: origin)
    @botuser = BotUser.instance

    if concept.published?
      @botuser.can? :branch, concept
    else
      @botuser.can? :update, concept
    end

    @published_concept = Iqvoc::Concept.base_class.by_origin(origin).published.last
    @unpublished_concept = Iqvoc::Concept.base_class.by_origin(origin).unpublished.last
    render_response :concept_locked and return if @unpublished_concept && @unpublished_concept.locked?
  end

  def render_response(type)
    message = messages[type]
    respond_to do |format|
      format.json { render message }
    end
  end

  def messages
    {
      mapping_added:    { status: 200, json: { type: 'concept_mapping_created', message: 'Concept mapping created.'} },
      mapping_removed:  { status: 200, json: { type: 'concept_mapping_removed', message: 'Concept mapping removed.'} },
      parameter_missing:{ status: 400, json: { type: 'parameter_missing', message: 'Required parameter missing.'} },
      unknown_relation: { status: 400, json: { type: 'unknown_relation', message: 'Concept or relation is wrong.'} },
      unknown_match:    { status: 400, json: { type: 'unknown_match', message: 'Unknown match class.' } },
      no_referer:       { status: 400, json: { type: 'no_referer', message: 'Referer is not set.' } },
      unknown_referer:  { status: 403, json: { type: 'unknown_referer', message: 'Unknown referer.' } },
      concept_locked:   { status: 423, json: { type: 'concept_locked', message: 'Concept is locked.' } },
      server_error:     { status: 500, json: {} }
    }
  end
end
