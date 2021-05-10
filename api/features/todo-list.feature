Feature: Todo list
  In order to record my tasks
  As a user
  I need to manage my todo items

  Rules:
  - Maximum 200 characters in toto item

  Scenario: Create new item
    Given there is 0 todo item
    When I create new todo item with following datas
    Then I should see 1 item in todo list

  Scenario: Delete item
    Given there is 5 todo items
    When I delete 1 item
    Then I should see 4 items in todo list