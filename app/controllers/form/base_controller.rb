# form section配下コントローラの共通親（04 R3・03§3決定Cのform区分）。
class Form::BaseController < ApplicationController
  include FormAuthenticatable
end
