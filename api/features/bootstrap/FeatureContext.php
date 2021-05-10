<?php

use Behat\Behat\Tester\Exception\PendingException;
use Behat\Behat\Context\Context;
use Behat\Gherkin\Node\PyStringNode;
use Behat\Gherkin\Node\TableNode;

/**
 * Defines application features from the specific context.
 */
class FeatureContext implements Context
{
    /**
     * Initializes context.
     *
     * Every scenario gets its own context instance.
     * You can also pass arbitrary arguments to the
     * context constructor through behat.yml.
     */
    public function __construct()
    {
    }

    /**
     * @Given there is :nbTodoItems todo item(s)
     */
    public function thereIsTodoItems($nbTodoItems)
    {
        $this->todoItemFactory->create($nbTodoItems);
        throw new PendingException();
    }

    /**
     * @When I create new todo item with following datas
     */
    public function iCreateNewTodoItemWithFollowingDatas()
    {
        $todoItem = new TodoItem();
        $this->todoList->addNewItem($todoItem);
        throw new PendingException();
    }

    /**
     * @Then I should see :nbTodoItems item(s) in todo list
     */
    public function iShouldSeeItemsInTodoList($nbTodoItems)
    {
        PHPUnit_Framework_Assert::assertCount($nbTodoItems, $this->todoList->getTodoItems());
        throw new PendingException();
    }

    /**
     * @When I delete :todoItem item
     */
    public function iDeleteItem($todoItem)
    {
        $this->todoList->deleteItem($todoItem);
        throw new PendingException();
    }
}
