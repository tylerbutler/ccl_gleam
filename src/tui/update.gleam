/// Update function for the CCL test viewer TUI.
import gleam/dict
import gleam/int
import gleam/list
import test_loader
import tui/model.{type Model, FileListView, Model, TestDetailView, TestListView}
import tui/msg.{
  type Msg, Back, CancelFilter, ClearFilter, GoToBottom, GoToFileList,
  GoToTestDetail, GoToTestList, GoToTop, NavigateDown, NavigateUp, NextTest,
  Noop, PageDown, PageUp, PrevTest, Quit, Select, StartFilter, SuiteLoaded,
  UpdateFilter,
}

/// Update the model based on a message.
pub fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    NavigateUp -> #(navigate_up(model), [])
    NavigateDown -> #(navigate_down(model), [])
    PageUp -> #(page_up(model), [])
    PageDown -> #(page_down(model), [])
    GoToTop -> #(go_to_top(model), [])
    GoToBottom -> #(go_to_bottom(model), [])
    Select -> handle_select(model)
    Back -> #(handle_back(model), [])

    GoToFileList -> #(
      Model(..model, view: FileListView, selected_index: 0, scroll_offset: 0),
      [],
    )
    GoToTestList(path) -> handle_go_to_test_list(model, path)
    GoToTestDetail(path, index) -> #(
      Model(..model, view: TestDetailView(path, index)),
      [],
    )

    StartFilter -> #(
      Model(..model, filter: model.FilterState(..model.filter, active: True)),
      [],
    )
    UpdateFilter(text) -> #(
      Model(..model, filter: model.FilterState(text: text, active: True)),
      [],
    )
    ClearFilter -> #(Model(..model, filter: model.empty_filter()), [])
    CancelFilter -> #(
      Model(..model, filter: model.FilterState(..model.filter, active: False)),
      [],
    )

    msg.FilesLoaded(_) -> #(model, [])
    SuiteLoaded(path, result) ->
      case result {
        Ok(suite) -> #(
          Model(
            ..model,
            loaded_suites: dict.insert(model.loaded_suites, path, suite),
          ),
          [],
        )
        Error(_) -> #(model, [])
      }

    NextTest -> #(next_test(model), [])
    PrevTest -> #(prev_test(model), [])
    Quit -> #(model, [])
    Noop -> #(model, [])
  }
}

fn navigate_up(model: Model) -> Model {
  let new_index = int.max(0, model.selected_index - 1)
  Model(..model, selected_index: new_index)
  |> model.adjust_scroll(get_item_count(model))
}

fn navigate_down(model: Model) -> Model {
  let count = get_item_count(model)
  let new_index = int.min(count - 1, model.selected_index + 1)
  Model(..model, selected_index: new_index)
  |> model.adjust_scroll(count)
}

fn page_up(model: Model) -> Model {
  let page_size = model.terminal_height - 5
  let new_index = int.max(0, model.selected_index - page_size)
  Model(..model, selected_index: new_index)
  |> model.adjust_scroll(get_item_count(model))
}

fn page_down(model: Model) -> Model {
  let count = get_item_count(model)
  let page_size = model.terminal_height - 5
  let new_index = int.min(count - 1, model.selected_index + page_size)
  Model(..model, selected_index: new_index)
  |> model.adjust_scroll(count)
}

fn go_to_top(model: Model) -> Model {
  Model(..model, selected_index: 0, scroll_offset: 0)
}

fn go_to_bottom(model: Model) -> Model {
  let count = get_item_count(model)
  let new_index = int.max(0, count - 1)
  Model(..model, selected_index: new_index)
  |> model.adjust_scroll(count)
}

fn get_item_count(model: Model) -> Int {
  case model.view {
    FileListView -> list.length(model.files)
    TestListView(path) ->
      case dict.get(model.loaded_suites, path) {
        Ok(suite) -> list.length(suite.tests)
        Error(_) -> 0
      }
    TestDetailView(_, _) -> 0
  }
}

fn handle_select(model: Model) -> #(Model, List(fn() -> Msg)) {
  case model.view {
    FileListView ->
      case list.drop(model.files, model.selected_index) {
        [file, ..] -> handle_go_to_test_list(model, file.path)
        [] -> #(model, [])
      }
    TestListView(path) -> #(
      Model(..model, view: TestDetailView(path, model.selected_index)),
      [],
    )
    TestDetailView(_, _) -> #(model, [])
  }
}

fn handle_back(model: Model) -> Model {
  case model.view {
    FileListView -> model
    TestListView(_) ->
      Model(..model, view: FileListView, selected_index: 0, scroll_offset: 0)
    TestDetailView(path, _) ->
      Model(
        ..model,
        view: TestListView(path),
        selected_index: 0,
        scroll_offset: 0,
      )
  }
}

fn handle_go_to_test_list(
  model: Model,
  path: String,
) -> #(Model, List(fn() -> Msg)) {
  case dict.get(model.loaded_suites, path) {
    Ok(_) -> #(
      Model(
        ..model,
        view: TestListView(path),
        selected_index: 0,
        scroll_offset: 0,
      ),
      [],
    )
    Error(_) -> {
      let load_task = fn() {
        let result = test_loader.load_test_file(path)
        SuiteLoaded(path, result)
      }
      #(
        Model(
          ..model,
          view: TestListView(path),
          selected_index: 0,
          scroll_offset: 0,
          message: "Loading...",
        ),
        [load_task],
      )
    }
  }
}

fn next_test(model: Model) -> Model {
  case model.view {
    TestDetailView(path, index) ->
      case dict.get(model.loaded_suites, path) {
        Ok(suite) -> {
          let max_index = list.length(suite.tests) - 1
          let new_index = int.min(max_index, index + 1)
          Model(..model, view: TestDetailView(path, new_index))
        }
        Error(_) -> model
      }
    _ -> model
  }
}

fn prev_test(model: Model) -> Model {
  case model.view {
    TestDetailView(path, index) -> {
      let new_index = int.max(0, index - 1)
      Model(..model, view: TestDetailView(path, new_index))
    }
    _ -> model
  }
}
