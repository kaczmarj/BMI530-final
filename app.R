#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

# How to show interactive 3d graphics using webgl:
# https://stackoverflow.com/q/44100268/5666087

library(rgl)
library(shiny)

# Define UI ----
ui <- fluidPage(
  titlePanel("Somatic mutations in TCGA"),

  # Sidebar on left and main panel on right ----
  sidebarLayout(
    # User inputs ----
    sidebarPanel(
      selectInput(
        "geneQuery",
        "Select a gene",
        c("KRAS", "TP53"),
      ),
      sliderInput("numSamples", label = "n samples", min = 10, max = 100, value = 10, step = 10),
    ),

    # Space for plots to be rendered ----
    mainPanel(
      textOutput("textOfGeneQuery"),
      rglwidgetOutput("plot3d", width = 800, height = 600),
    ),
  )
)

# Define server logic required ----
server <- function(input, output) {
  # Render text based on the user input ----
  output$textOfGeneQuery <- renderText({
    sprintf("You selected %s", input$geneQuery)
  })

  output$plot3d <- renderRglwidget({
    n <- input$numSamples
    try(close3d())
    plot3d(rnorm(n), rnorm(n), rnorm(n))
    rglwidget()
  })
}

# Run the application ----
shinyApp(ui = ui, server = server)
