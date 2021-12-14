# Shiny app that displays safety information about cars.
# Uses the API from the National Highway Traffic Safety Administration (NHTSA).

library(curl)
library(jsonlite)
library(shiny)

# Read data from a URL and return NULL on error.
# https://stackoverflow.com/a/12195574/5666087
readURL <- function(url) {
  con <- curl::curl(url)
  out <- tryCatch(
    expr = {
      readLines(con = con, warn = FALSE)
    },
    error = function(cond) {
      message(paste("Error getting", url))
      message("Here's the original error message:")
      message(cond)
      return(NULL)
    },
    finally = {
      close(con)
    }
  )
  return(out)
}

# Define UI ----
ui <- {
  fluidPage(
    titlePanel("How safe is your car? Find out using public data from NHTSA.gov"),

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
        selectizeInput(
          inputId = "vehicleVariantID",
          label = "Select a variant",
          choices = NULL,
        ),
        # This is out of 12.
        width = 4
      ),

      # Space for data to be rendered ----
      mainPanel(fluidRow(column(
        12,
        fluidRow(textOutput("vehicleInfo")),
        fluidRow(
          column(4, tableOutput(
            "vehicleCrashTable"
          )),
          column(
            8,
            fluidRow(
              column(6, tableOutput(
                "vehicleAssistTable"
              )),
              column(6, tableOutput(
                "vehicleRecallTable"
              )),
            ),
            fluidRow(htmlOutput("vehicleImage")),
          )
        )
      )), )
    ),
    hr(),
    fluidRow(column(
      12,
      align = "center",
      tags$a(
        href = "https://github.com/kaczmarj/car-safety-shiny",
        target = "_blank",
        rel = "noopener",
        "View source",
        icon("fab fa-github")
      ),
      "|",
      tags$a(
        href = "https://github.com/kaczmarj/car-safety-shiny/issues/new",
        "Report a problem",
        target = "_blank",
        rel = "noopener"
      ),
    )),
  )
}

# Get vehicle makes ----
# Column names are make_id and make_name.
# TODO: can we run this outside of server and client?
vehicleMakes <- {
  res <-
    readURL("https://vpic.nhtsa.dot.gov/api/vehicles/GetAllMakes?format=csv")
  if (is.null(res)) {
    NULL
  } else {
    read.csv(text = res)
  }
}

# We make these objects global for easier debugging.
vehicleModels <- NULL
vehicleTypes <- NULL
vehicleDescriptionsAndIDs <- NULL
vehicleSafety <- NULL

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
        url <-
          sprintf(
            "https://vpic.nhtsa.dot.gov/api/vehicles/GetVehicleTypesForMake/%s?format=csv",
            make
          )
        url <- URLencode(url)
        res <- readURL(url)
        if (is.null(res)) {
          NULL
        } else {
          read.csv(text = res)
        }
      }
      if (is.null(vehicleTypes)) {
        return(NULL)
      }
      vehicleTypeChoices <-
        sort(unique(trimws(vehicleTypes$vehicletypename)))
      selected <-
        if ("Passenger Car" %in% vehicleTypeChoices) {
          "Passenger Car"
        } else {
          NULL
        }
      updateRadioButtons(
        session = session,
        inputId = "vehicleType",
        # We need to trim whitespace because some names come with whitespace.
        choices = vehicleTypeChoices,
        selected = selected
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
        res <- readURL(url)
        if (is.null(res)) {
          NULL
        } else {
          read.csv(text = res)
        }
      }
      if (is.null(vehicleModels)) {
        return(NULL)
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
      input$vehicleYear != "",
      input$vehicleMake != "",
      input$vehicleModel != "",
      !is.null(vehicleModels)
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

    url <-
      sprintf(
        "https://api.nhtsa.gov/SafetyRatings/modelyear/%s/make/%s/model/%s",
        year,
        make,
        model
      )
    url <- URLencode(url)
    allSelected <- all(
      year != "", make != "",
      model != "", !is.null(vehicleModels)
    )

    if (allSelected) {
      # Reset image.
      output$vehicleImage <- renderText("Photo unavailable")

      # TODO: should we reset the tables here too?
      res <- readURL(url)
      if (is.null(res)) {
        return(NULL)
      }
      vehicleDescriptionsAndIDs <<- jsonlite::fromJSON(res)$Results
      if (!is.null(vehicleDescriptionsAndIDs) &&
        length(vehicleDescriptionsAndIDs) == 0) {
        # what do?
      } else {
        updateSelectizeInput(
          session = session,
          inputId = "vehicleVariantID",
          choices = split(
            vehicleDescriptionsAndIDs$VehicleId,
            vehicleDescriptionsAndIDs$VehicleDescription
          )
        )
      }
    }
  })

  # Get safety information using the vehicle ID ----
  observe({
    # A number (actually a string in this case) that is unique to each car.
    vehicleId <- input$vehicleVariantID

    if (vehicleId == "") {
      return()
    }

    # Get safety information...
    url <-
      sprintf(
        "https://api.nhtsa.gov/SafetyRatings/VehicleId/%s",
        vehicleId
      )
    url <- URLencode(url)
    # For debugging: https://api.nhtsa.gov/SafetyRatings/VehicleId/13679
    # url above is for 2019 golf
    res <- readURL(url)
    if (is.null(res)) {
      return(NULL)
    }
    vehicleSafety <<- jsonlite::fromJSON(res)$Results

    crashNames <- c(
      "OverallRating",
      "OverallFrontCrashRating",
      "FrontCrashDriversideRating",
      "FrontCrashPassengersideRating",
      "OverallSideCrashRating",
      "SideCrashDriversideRating",
      "SideCrashPassengersideRating",
      "RolloverRating",
      "RolloverRating2",
      "RolloverPossibility",
      "RolloverPossibility2",
      "SidePoleCrashRating"
    )

    assistNames <-
      c(
        "NHTSAElectronicStabilityControl",
        "NHTSAForwardCollisionWarning",
        "NHTSALaneDepartureWarning"
      )

    recallNames <-
      c("ComplaintsCount", "RecallsCount", "InvestigationCount")

    output$vehicleCrashTable <- renderTable({
      # Transpose the dataframe so column names become row values.
      df <- as.data.frame(t(vehicleSafety[, crashNames]))
      cbind("Crash test" = rownames(df), Value = df[, 1])
    })

    output$vehicleAssistTable <- renderTable({
      # Transpose the dataframe so column names become row values.
      df <- as.data.frame(t(vehicleSafety[, assistNames]))
      cbind("Assist system" = rownames(df), Value = df[, 1])
    })

    output$vehicleRecallTable <- renderTable({
      # Transpose the dataframe so column names become row values.
      df <- as.data.frame(t(vehicleSafety[, recallNames]))
      cbind("Bad news" = rownames(df), Value = df[, 1])
    })

    output$vehicleImage <- renderText({
      c(sprintf(
        '<img src="%s" width="500px">',
        vehicleSafety$VehiclePicture
      ))
    })
  })
}

# Run the application ----
shinyApp(ui = ui, server = server)
