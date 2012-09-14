class TweetsController < ApplicationController
  # GET /tweets
  # GET /tweets.xml

  caches_action :index, 
    :expires_in => 30.minutes,
    :if => proc { (params.keys - ['format', 'action', 'controller']).empty? }

  def index

    @states_list = Politician.all(:select => "DISTINCT(state)")
    @states = []
    @states_list.each do |sl|
      if sl.state != nil 
        @states.push(sl.state)
      end
    end
    @states = @states.sort

    @parties = Party.all
    @offices = Office.all

    @politicians = Politician.active

    #check for filters
    @filters = {'state' => nil, 'party' => nil, 'office' => nil  }
    if params.has_key?(:state) && params[:state] != ""
        @politicians = @politicians.where(:state => params[:state])
        @filters['state'] = params[:state]
    end
    if params.has_key?(:party) && params[:party] != ""
        party = Party.where(:name => params[:party])[0]
        @politicians = @politicians.where(:party_id => party)
        @filters['party'] = party.name
    end
    if params.has_key?(:office) && params[:office] != ""
        @politicians = @politicians.where(:office_id => params[:office])
        @filters['office'] = params[:office]
    end



    if params.has_key?(:see) && params[:see] == :all
      @tweets = Tweet
    else
      @tweets = DeletedTweet
    end

    @tweets = @tweets.where(:politician_id => @politicians)
    tweet_count = 0 #@tweets.count

    if params.has_key?(:q) and params[:q].present?
      # Rails prevents injection attacks by escaping things passed in with ?
      @query = params[:q]
      query = "%#{@query}%"
      @tweets = @tweets.where("content like ? or deleted_tweets.user_name like ?", query, query)
    end

    # only approved tweets
    @tweets = @tweets.where(:approved => true)

    per_page = params[:per_page] ? params[:per_page].to_i : nil
    per_page ||= Tweet.per_page
    per_page = 200 if per_page > 200

    @tweets = @tweets.includes(:politician => [:party]).paginate(:page => params[:page], :per_page => per_page)

    respond_to do |format|
      format.html # index.html.erb
      format.rss  do
        response.headers["Content-Type"] = "application/rss+xml; charset=utf-8"
        render
      end
      format.json { render :json => {:meta => {:count => tweet_count}, :tweets => @tweets.map{|tweet| tweet.format } } }
    end
  end

  # GET /tweets/1
  # GET /tweets/1.xml
  def show
    @tweet = DeletedTweet.includes(:politician).find(params[:id])

    not_found unless @tweet.politician.status == 1
    not_found unless @tweet.approved?

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tweet }
      format.json  { render :json => @tweet.format }
    end
  end
end
