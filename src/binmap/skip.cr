module Binary
  class Skip
    def intialize
    end

    def self.new(io : ::IO, params)
      io.skip(params[:size])
      new
    end
  end
end
