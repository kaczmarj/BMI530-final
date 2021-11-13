#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

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
      )
    ),

    # Space for plots to be rendered ----
    mainPanel(
      textOutput("textOfGeneQuery")
    ),
  )
)

# Define server logic required ----
server <- function(input, output) {

  # Render text based on the user input ----
  output$textOfGeneQuery <- renderText({
    sprintf("You selected %s", input$geneQuery)
  })
}

# Run the application ----
shinyApp(ui = ui, server = server)
