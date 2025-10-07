module Platform
  module Admin
    class AgenciesController < BaseController
      def index
        @agencies = Agency.includes(:users, :agency_memberships)
                         .order(created_at: :desc)
                         .page(params[:page]).per(25)
      end
      
      def show
        @agency = Agency.find(params[:id])
        @members = @agency.agency_memberships.includes(:user).order(created_at: :asc)
        @clients = @agency.advertiser_agency_accesses.includes(:advertiser)
      end
      
      def new
        @agency = Agency.new
      end
      
      def create
        @agency = Agency.new(agency_params)
        
        # Find or create the owner user
        owner_email = params[:agency][:owner_email]
        owner = User.find_by(email: owner_email)
        
        unless owner
          flash.now[:error] = "User with email #{owner_email} not found. Please create the user first."
          return render :new, status: :unprocessable_entity
        end
        
        if @agency.save
          # Create owner membership
          @agency.agency_memberships.create!(
            user: owner,
            role: 'owner',
            status: 'accepted'
          )
          
          flash[:notice] = "Agency #{@agency.name} created successfully"
          redirect_to platform_admin_agency_path(@agency)
        else
          render :new, status: :unprocessable_entity
        end
      end
      
      private
      
      def agency_params
        params.require(:agency).permit(
          :name,
          :street_address,
          :city,
          :state,
          :postal_code,
          :country,
          :website_url
        )
      end
    end
  end
end

