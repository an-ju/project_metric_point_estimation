require "project_metric_point_estimation/version"
require "faraday"
require "json"

class ProjectMetricPointEstimation
  attr_reader :raw_data

  def initialize(credentials, raw_data = nil)
    @project = credentials[:tracker_project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:tracker_token]
    @raw_data = raw_data
  end

  def refresh
    @score = @image = nil
    @raw_data ||= stories
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    @raw_data ||= stories
    l = @raw_data.length.to_f
    @score ||= @raw_data.reject { |s| get_estimation(s) < 0 }.length / l
  end

  def image
    @raw_data ||= stories
    point_buckets = @raw_data.map { |s| get_estimation s }.uniq.sort
    counting = point_buckets.map do |pnt|
      @raw_data.count { |s| get_estimation(s).eql? pnt }
    end
    @image ||= { chartType: 'point_estimation',
                 titleText: 'Point distribution',
                 data: { data: counting, series: point_buckets } }.to_json
  end

  def self.credentials
    %I[tracker_project tracker_token]
  end

  private

  def stories
    JSON.parse(@conn.get("projects/#{@project}/stories").body).reject do |s|
      s['current_state'].eql?('unstarted') || s['current_state'].eql?('unscheduled')
    end
  end

  def get_estimation(s)
    s['estimate'] ? s['estimate'] : -1
  end

end
