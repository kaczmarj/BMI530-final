# Shiny app that displays information about cars.
# Uses the API from the National Highway Traffic Safety Administration (NHTSA).

# Writeup, demo, github url.

# todo: make the select for make above, then vehicle type will be reactive.

library(shiny)

# Define UI ----
ui <- {
  fluidPage(
    titlePanel("What are people saying about your car?"),

    # Sidebar on left and main panel on right ----
    sidebarLayout(
      # User inputs ----
      sidebarPanel(
        selectInput(
          inputId = "vehicleYear",
          label = "Select a model year",
          choices = 1995:2023,
          selected = 2019
        ),
        selectizeInput(
          inputId = "vehicleMake",
          label = "Select a make (supports text search)",
          choices = NULL,
        ),
        radioButtons(
          inputId = "vehicleType",
          label = "Select a vehicle type",
          choices = c("Please wait"),
        ),
        selectizeInput(
          inputId = "vehicleModel",
          label = "Select a model",
          choices = NULL,
        ),
      ),

      # Space for data to be rendered ----
      mainPanel(
        fluidRow(textOutput("vehicleInfo")),
        fluidRow(textOutput("vehicleRatingOverall")),
        fluidRow(htmlOutput("vehicleImage")),
      ),
    )
  )
}

# Get vehicle makes ----
# Column names are make_id and make_name.
# TODO: can we run this outside of server and client?
vehicleMakes <-
  read.csv("https://vpic.nhtsa.dot.gov/api/vehicles/GetAllMakes?format=csv")

vehicleModels <- NULL
vehicleTypes <- NULL

# Define server logic ----
server <- function(input, output, session) {

  # See https://shiny.rstudio.com/articles/selectize.html#server-side-selectize
  # We set the choices here to improve performance.
  updateSelectizeInput(
    session = session,
    inputId = "vehicleMake",
    choices = sort(vehicleMakes$make_name),
    selected = "VOLKSWAGEN",
    server = TRUE
  )

  # Fill in the vehicle type options. ----
  observe({
    make <- input$vehicleMake

    # Do not make an API request unless we have selected a make...
    if (make %in% vehicleMakes$make_name) {
      vehicleTypes <<- {
        url <- sprintf("https://vpic.nhtsa.dot.gov/api/vehicles/GetVehicleTypesForMake/%s?format=csv", make)
        url <- URLencode(url)
        # TODO: add try-catch here to account for possible errors in request.
        read.csv(url)
      }
      updateRadioButtons(
        session = session,
        inputId = "vehicleType",
        # We need to trim whitespace because some names come with whitespace.
        choices = sort(trimws(vehicleTypes$vehicletypename))
      )
    }
  })


  # Update choices for vehicle make based on selected vehicle model. ----
  observe({
    year <- input$vehicleYear
    make <- input$vehicleMake
    type <- input$vehicleType

    # Do not make an API request unless we have selected a make...
    if (make %in% vehicleMakes$make_name) {
      # Note the <<- operator, so we update the variable in the parent scope.
      vehicleModels <<- {
        url <-
          sprintf(
            "https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/%s/modelyear/%s/vehicletype/%s?format=csv",
            make,
            year,
            type
          )
        url <- URLencode(url)
        # TODO: add try-catch here to account for possible errors in request.
        read.csv(url)
      }
      updateSelectizeInput(
        session = session,
        inputId = "vehicleModel",
        choices = sort(vehicleModels$model_name)
      )
    }
  })
  output$vehicleInfo <- renderText({
    allSelected <- all(
      input$vehicleYear != "", input$vehicleMake != "",
      input$vehicleModel != "", !is.null(vehicleModels)
    )
    if (allSelected) {
      # Render text based on the user input ----
      sprintf(
        "%s %s %s",
        input$vehicleYear,
        input$vehicleMake,
        input$vehicleModel
      )
    }
  })

  observe({
    year <- input$vehicleYear
    make <- input$vehicleMake
    model <- input$vehicleModel

    url <- sprintf("https://api.nhtsa.gov/SafetyRatings/modelyear/%s/make/%s/model/%s", year, make, model)
    url <- URLencode(url)
    allSelected <- all(
      year != "", make != "",
      model != "", !is.null(vehicleModels)
    )

    if (allSelected) {
      # Reset image.
      output$vehicleImage <- renderText("Photo unavailable")

      results <- jsonlite::fromJSON(url)$Results
      if (!is.null(results) && length(results) == 0) {
        # what do?
      } else {
        # Has names VehicleDescription and VehicleId
        vehicleInfo <- results[1, ]
        vehicleId <- vehicleInfo$VehicleId

        # Get safety information...
        url <- sprintf("https://api.nhtsa.gov/SafetyRatings/VehicleId/%s", vehicleId)
        url <- URLencode(url)
        vehicleSafety <- jsonlite::fromJSON(url)$Results[1]

        output$vehicleRatingOverall <- renderText({
          sprintf("Overall%s / 5", vehicleSafety$OverallRating)
        })

        output$vehicleImage <- renderText({
          c(sprintf('<img src="%s">', vehicleSafety$VehiclePicture))
        })
      }
    }
  })
}

# Run the application ----
shinyApp(ui = ui, server = server)
