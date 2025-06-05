class DebugController < ApplicationController
  def debug
    render plain: "Debug OK"
  end
end
