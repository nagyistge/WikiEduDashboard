require 'rails_helper'
require "#{Rails.root}/lib/training_module"

describe 'Training', type: :feature, js: true do
  let(:cohort) { create(:cohort) }
  let(:user)   { create(:user, id: 1) }
  let(:module_2) { TrainingModule.find(2) } # Policies and Guidelines module

  before do
    login_as(user, scope: :user)
    Capybara.current_driver = :selenium
  end

  describe 'module index page' do
    before do
      visit "/training/students/#{module_2.slug}"
    end

    it 'describes the module' do
      expect(page).to have_content module_2.name
      expect(page).to have_content 'Estimated time to complete'
      expect(page).to have_content module_2.estimated_ttc
    end

    it 'renders the table of contents' do
      expect(page).to have_content 'TABLE OF CONTENTS'
      expect(page).to have_content module_2.slides[0].title
      expect(page).to have_content module_2.slides[-1].title
    end

    it 'lets the user start the module' do
      click_link 'Start'
      slide_count = module_2.slides.count
      expect(page).to have_content "Page 1 of #{slide_count}"
      expect(TrainingModulesUsers.find_by(
               user_id: user.id,
               training_module_id: module_2.id
      )).not_to be_nil
    end

    it 'disables slides that have not been seen' do
      click_link 'Start'
      within('.training__slide__nav') { find('.hamburger').click }
      unseen_slide_link = find('.slide__menu__nav__dropdown li:last-child a')
      expect(unseen_slide_link['disabled']).to eq('true')
    end
  end

  module_ids = TrainingModule.all.map(&:id)
  module_ids.each do |module_id|
    training_module = TrainingModule.find(module_id)
    describe "'#{training_module.name}' module" do
      training_module = TrainingModule.find(module_id)
      it 'lets the user go from start to finish' do
        go_through_module_from_start_to_finish(training_module)
      end
    end
  end
end

def go_through_module_from_start_to_finish(training_module)
  slide_count = training_module.slides.count
  visit "/training/students/#{training_module.slug}"
  click_link 'Start'
  training_module.slides.each_with_index do |slide, i|
    check_slide_contents(slide, i, slide_count)
    unless i == slide_count - 1
      proceed_to_next_slide
      next
    end
    click_link 'Done!'
    sleep 1
    expect(TrainingModulesUsers.find_by(
      user_id: 1,
      training_module_id: training_module.id
    ).completed_at).not_to be_nil
  end
end

def check_slide_contents(slide, slide_number, slide_count)
  expect(page).to have_content slide.title
  expect(page).to have_content "Page #{slide_number + 1} of #{slide_count}"
end

def proceed_to_next_slide
  button = page.first('button.ghost-button')
  find_correct_answer_by_trial_and_error unless button.nil?
  click_link 'Next Page'
end

def find_correct_answer_by_trial_and_error
  (1..10).each do |current_answer|
    page.all('input')[current_answer].click
    click_button 'Check Answer'
    next_button = page.first('a.slide-nav.btn.btn-primary')
    break unless next_button['disabled'] == 'true'
  end
end