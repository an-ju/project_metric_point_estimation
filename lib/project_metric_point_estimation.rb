require "project_metric_point_estimation/version"
require "faraday"
require "json"
require "time"

class ProjectMetricPointEstimation
  attr_reader :raw_data

  def initialize(credentials, raw_data = nil)
    @project = credentials[:project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:token]
    @raw_data = raw_data
  end

  def image
    refresh unless @raw_data
    { chartType: 'point_estimation',
      titleText: 'Point Estimation',
      data: @raw_data }.to_json
  end

  def refresh
    @raw_data = stories.map { |s| estimation s }
    @raw_data.select { |s| s['dev_time'] }
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    refresh unless @raw_data
    @score = @raw_data.length
  end

  private

  def project
    JSON.parse(
        @conn.get("projects/#{@project}").body
    )
  end

  def stories
    JSON.parse(
        @conn.get("projects/#{@project}/stories").body
    )
  end

  def transitions(story_id)
    JSON.parse(
        @conn.get("projects/#{@project}/stories/#{story_id}/transitions").body
    )
  end

  def estimation(story)
    state_changes = {}
    transitions(story['id']).each do |t|
      state_changes[t['state']] = Time.parse t['occurred_at']
    end
    if state_changes.key? 'started' and state_changes.key? 'finished'
      story['dev_time'] = state_changes['finished'] - state_changes['started']
    end
    story
  end
end
