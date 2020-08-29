## Load functions in current working directory
src_files <- list.files("R/", full.names = TRUE)
sapply(src_files, function(x) source(x))

## Load R Packages
#Shiny-related
library(shiny)
library(dashboardthemes)
library(shinythemes)
library(shinydashboard)
library(DT)
#GIS
library(sf)
library(raster)
library(sp)
library(rgdal)
library(raster)
library(caTools)
library(maptools)
library(maps)
library(rgeos)
library(geosphere)
#Plotting
library(ggplot2)
library(ggrepel)
library(plotly)
#Misc
library(tidyr)
library(stringr)
library(tidyverse)
library(dplyr)

## Variable transformation function
transform_data <- function(x){
  min_x = min(x, na.rm=TRUE)
  max_x = max(x, na.rm=TRUE)
  mean_x = mean(x, na.rm=TRUE)
  y = (x-mean_x)/(max_x-min_x)
  return(y)
}

## Set page variables
p4s_ll <- CRS("+proj=longlat")
d <- readRDS("county_data.rds")
counties <- as(d, "Spatial")
proj4string(counties) <- p4s_ll
centroids <-
  sapply(d$geometry, function(x)
    colMeans(x[[1]][[1]])) %>% t %>% data.frame()
d$long = centroids[, 1]
d$lat = centroids[, 2]
d2 <- readRDS("summary_data.rds")
d2 <- d2 %>% 
  mutate(Population = exp(Population)) %>% 
  mutate(Population = round(Population)) %>% 
  mutate(Median_Income = exp(Median_Income)) %>%
  mutate(Median_Income = round(Median_Income))
menuOpts <- d[, c("county", "state")] %>% data.frame()
menuOpts$geometry <- NULL
menuOpts$state <-
  menuOpts$state %>%
  str_replace_all(pattern = "_", replacement = " ") %>%
  str_to_title()
menuOpts$county <-
  menuOpts$county %>%
  str_replace_all(pattern = "_", replacement = " ") %>%
  str_to_title()
slider_width <- "85%"
label_county = HTML('<p style="color:black;margin-left:45px">County</p>')
label_state = HTML('<p style="color:black;margin-left:45px">State</p>')


## Create Python virtual environment
reticulate::virtualenv_create(envname = "python_environment", python = "python3")
reticulate::virtualenv_install(envname = "python_environment", packages = c("geopy"), ignore_installed = TRUE)
reticulate::use_virtualenv("python_environment", required = TRUE)
reticulate::source_python("Python/city_coords.py")


## Create sidebar for app
sidebar <- dashboardSidebar(
    disable = TRUE,
  width = 300
)

## Create body of dashboard page
body <- dashboardBody(
  #changing theme
  style = "height:100%;margin-left:10%;margin-right:10%;margin-top:0%",
  fluidPage(
    theme = shinytheme("flatly"),
    fluidRow(column(12, align="center",
                    h1(HTML("<u>Niche: An Interface for Exploring Moving Options</u>")),
                    br(),
                    h4("Whether you are looking for familiar surroundings or want to experience something new, Niche can help you smartly explore your relocation options. The program aggregates numerous sources of county-level data covering everything from the climate, land development, politics, cost of living, and demographics. Niche considers the factors most important to you when making its recommendations. You may be surprised when you find out where that a perfect destination awaits.")
                    )
             ),
    br(),
    fluidRow(
    column(3, align="left",
           h4(
             HTML(
               "<p style='color:black;margin-left:30px'>Answer below on a scale of 1-5</p>"
             )
           ),
           h5(
             HTML(
               "<p style='color:black;margin-left:10px'>(1 - not important, 3 - neutral, 5 - very important)</p>"
             )
           ),
           sliderInput(
             inputId = "feat_im_climate",
             label = HTML(
               "<p style='color:black;margin-left:35px'>How important is the climate?</p>"
             ),
             step = 1,
             min = 1,
             max = 5,
             value = 3,
             width = slider_width
           ),
           sliderInput(
             inputId = "feat_im_soc",
             label = HTML(
               "<p style='color:black;margin-left:40px'>What about demographics (age structure, education, diversity, etc.)?</p>"
             ),
             min = 1,
             max = 5,
             value = 3,
             width = slider_width
           ),
           sliderInput(
             inputId = "feat_im_econ",
             label = HTML(
               "<p style='color:black;margin-left:40px;vertical-align:center'>The local economy (household income, urban development, poverty rate, etc.)?</p>"
             ),
             min = 1,
             max = 5,
             value = 3,
             width = slider_width
           ),
           sliderInput(
             inputId = "feat_im_political",
             label = HTML(
               "<p style='color:black;margin-left:40px'>A similar political atmosphere?</p>"
             ),
             min = 1,
             max = 5,
             value = 3,
             width = slider_width
           ),
           sliderInput(
             inputId = "feat_im_pa",
             label = HTML(
               "<p style='color:black;margin-left:35px'>Public lands and recreation?</p>"
             ),
             min = 1,
             max = 5,
             value = 3,
             width = slider_width
           )
    ),
    column(3, align="left",
           h4(
             HTML(
               '<p style="color:black;margin-left:35px">Enter the name of a city...</p>'
             ),
             .noWS = "outside"
           ),
           splitLayout(
             div(style="text-align:center;"),
             cellWidths = c("0%","65%","0%", "20%"),
             textInput(
               "city",
               label = "",
               placeholder = "San Francisco, CA",
               value = "",
               width = "100%"
             ),
             tags$style(type = "text/css", "#city {text-align:center}"),
             actionButton("search",
                          label = "",
                          width = "100%",
                          icon=icon("binoculars")
             ),
             tags$style(type = "text/css", "#search {display: inline-block;text-align: center;margin-top:27%;margin-right:30%}")),
           br(),
           br(),
           h4(
             HTML(
               '<p style="color:black;margin-left:35px">...Or find a location with the menu...</p>'
             ),
             .noWS = "outside"
           ),
           br(),
           br(),
           splitLayout(
             tags$head(tags$style(
               HTML("
                 .shiny-split-layout > div {
                 overflow: visible;
                 }
                 ")
             )),
             cellWidths = c("0%", "50%", "50%"),
             selectInput(
               #selectize = TRUE,
               "state",
               label = label_state,
               selected = NULL,
               choices = unique(menuOpts$state)
             ),
             selectInput(
               #selectize = TRUE,
               "county",
               label = label_county,
               selected = NULL,
               choices = ""
             )
           ),
           br(),
           splitLayout(
             tags$head(tags$style(
               HTML("
                 .shiny-split-layout > div {
                 overflow: visible;
                 }
                 ")
             )),
             cellWidths = c("0%", "80%", "20%"),
             checkboxInput(
               inputId = "out_of_state",
               label = HTML(
                 "<p style='color:black;margin-left:0px'>Only list locations in other states?</p>"
               )
             ),
             # tags$style(type = "text/css", "#out_of_state {margin-left:10px}"),
             numericInput(
               inputId = "n_labels",
               label = HTML(
                 "<b style='color:black;margin-left:5px'>Labels</b>"
               ),
               min = 5,
               max = 30,
               step = 1,
               value = 10
             )
           ),
           br(),
           actionButton("find",
                        label = HTML("<b>Find Your Niche</b>"),
                        width = "50%"),
           tags$style(type = "text/css", "#find {text-align:center; margin-left:25%}")
    ),
    br(),
    column(
      6,
      align = "center",
      fluidRow(tags$head(
        tags$style(".shiny-output-error{color:blue; font-size: 17px}")
      )),
      h4(HTML("<p>Counties with scores closer to 1 are more similar to the target location.</p>")),
      fluidRow(plotlyOutput("map", height = "550px"))
    )),
    br(),
    br(),
    br(),
    column(
      12,
      align = "center",
      fluidRow(tags$head(
        tags$style(".shiny-output-error{color:blue; font-size: 17px}")
      )),
      fluidRow(
        h4(HTML("<p>Click on the links under 'Find_homes' and 'Location' to search the area on Zillow and Google.</p>")),
        dataTableOutput("focal_table", width="100%"),
         br(),
        dataTableOutput("table", width="100%")
      )
    )
  )
)

## UI
ui = dashboardPage(
  dashboardHeader(title = "Niche: Easier Moving Decisions", titleWidth =
                    350),
  sidebar,
  body
)

## Server logic
server = function(input, output, session) {
  
  state <- reactive({
    filter(menuOpts, state == input$state)
  })
  
  # Display report topic menu options based on report type
  observeEvent(state(), {
    choices <- sort(unique(state()$county))
    if(input$city!=""){
      loc_data <-
        city_coords(input$city) %>%
        matrix(., ncol = 2) %>%
        SpatialPoints(., p4s_ll) %>%
        over(., counties)
      county = loc_data["county"]$county %>% 
        str_replace_all(pattern = "_", replace=" ") %>%
        str_to_title()
      updateSelectInput(session, "county", choices = choices, selected=county)
    } else{
      updateSelectInput(session, "county", choices = choices)
    }
  })
  
  #Dynamic input menu
  observeEvent(input$search, {
    #input$search
    print("test")
    loc_data <-
      city_coords(input$city) %>%
      matrix(., ncol = 2) %>%
      SpatialPoints(., p4s_ll) %>%
      over(., counties)
    state <- loc_data["state"]$state %>% 
      str_replace_all(pattern = "_", replace=" ") %>%
      str_to_title()
    if(input$city==""){
      state <- "Alabama"
    }
    updateSelectInput(session, "state", selected = state)
  })
  
  map <- eventReactive(input$find, {
    #Start progress update
    progress <- Progress$new(session, min = 1, max = 3)
    on.exit(progress$close())
    progress$set(message = 'Gathering data...',
                 detail = '')
    progress$set(value = 1)
    
    ## Plot the features
    input_county = input$county
    input_state = input$state
    focal_location = paste(input_county, input_state, sep = ",_") %>%
      str_replace_all(" ", "_") %>%
      tolower()
    
    climate_vars = paste0("CLIM_PC", 1:3)
    social_vars = c("total_population","white_pct","black_pct","hispanic_pct","foreignborn_pct",
                    "age29andunder_pct","age65andolder_pct","rural_pct")
    economic_vars = c("Median_HH_Inc","clf_unemploy_pct","poverty_pct","lesscollege_pct","lesshs_pct")
    political_vars = c("trump16_pct","romney12_pct")
    landscape_vars = paste0("LandCover_PC",1:4)
    features = c(
      climate_vars,
      social_vars,
      economic_vars,
      political_vars,
      landscape_vars
    )
    weights = c(rep((input$feat_im_climate - 1) / 2, 3),
                rep((input$feat_im_soc - 1) / 2, length(social_vars)),
                rep((input$feat_im_econ - 1) / 2, length(economic_vars)),
                rep((input$feat_im_pol - 1) / 2, length(political_vars)),
                rep(1, length(landscape_vars))
                )
    
    vals <- d[, features]
    vals$geometry <- NULL
    vals <- vals * weights
    vals <- apply(vals,2,transform_data)
    vals_t <- t(vals)
    attr(vals_t, "dimnames") <- NULL
    #Cosine similarity
    focal_index <-
      which(d$name == focal_location) #index of focal location
    Score = cos_prox(vals_t, focal_index, measure = "proximity")
    
    progress$set(message = 'Creating map...',
                 detail = '')
    
    state_df <- map_data("state")
    d$Score <- ((Score + 1) / 2) %>% round(2)
    title. = sprintf("Similarity to %s, %s", str_to_title(input_county), str_to_title(input_state)) #plot title
    d$label = paste(d$county, d$state, sep = ", ") %>%
      str_replace_all(pattern = "_", replacement = " ") %>%
      str_to_title() #location labels (County, State)
    d. <- cbind(d$Score, d2)
    names(d.) <-
      c(c("Score", "County", "State"), names(d.)[-c(1:3)])
    saveRDS(d., "new_table.rds") #save to storage
    d <- d[order(d$Score, decreasing = TRUE),] #sort by SCORE DESC
    if (input$out_of_state) {
      d$Score[d$state==input$state] <- NA
      dlabel = d %>%
        filter(state != tolower(input$state))
      dlabel <- dlabel[1:input$n_labels, ]
    }
    else{
      dlabel <- d[1:input$n_labels, ]
    }
    
    
    progress$set(message = 'Converting map to Plotly object...',
                 detail = 'This may take several moments.')
    progress$set(value = 2)
    
    
    p <- ggplot(d) +
      ggtitle(title., subtitle = "Scores close to 1 are most similar") +
      theme_void() +
      theme(
        text = element_text(family = "Helvetica"),
        plot.title = element_text(
          size = 20,
          face = "bold",
          hjust = 0.0
        ),
        plot.subtitle = element_text(size = 17, hjust = 0.0),
        panel.background = element_rect(fill = "gray99"),
        legend.position = c(0.2, 0.15),
        legend.direction = "horizontal",
        legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"),
        legend.title = element_text(
          face = "bold",
          size = 14.5,
          vjust = 1
        ),
        legend.text = element_text(size = 13)
      ) +
      geom_point(
        mapping=aes(x=long, y=lat, text=label, label=Score)
      ) +
      geom_sf(
        show.legend = TRUE,
        mapping = aes(fill = Score),
        color = "black",
        size = 0.1
      ) +
      geom_path(
        data = state_df,
        show.legend = TRUE,
        mapping = aes(x=long, y=lat, group=group),
        color = "white",
        size = 0.2
      ) +
      guides(fill = guide_colorbar()) +
      scale_fill_viridis_c(
        "Score",
        direction = 1,
        breaks = seq(0, 1, 0.25),
        labels = c("0.0", "", "0.5", "", "1.0"),
        limits = c(0, 1)
      )
    
      p2 <- ggplotly(p, tooltip = c("text","label"))

    progress$set(value = 3)
    
    return(p2)
    
  })
  
  table <- eventReactive(input$find, {
    dx = readRDS("new_table.rds")
    if (input$out_of_state) {
      dx <- dx %>%
        filter(State != input$state)
    }
    d_out = dx[order(dx$Score, decreasing = TRUE),]
    zillowQuery <-
      sprintf("%s-county,-%s",
              tolower(d_out$County),
              tolower(d_out$State))
    url <-
      sprintf("https://www.zillow.com/homes/%s_rb/", zillowQuery)
    Find_homes <- sprintf("<a href='%s'>Find homes</a>", url)
    googleQuery = sprintf("%s+county%s+%s", d_out$County, "%2C", d_out$State) %>%
      str_replace_all(pattern = "_", replacement = "+") %>%
      tolower()
    google_url <-
      sprintf("https://google.com/search?q=%s", googleQuery)
    Location <-
      sprintf("<a href='%s'>%s, %s</a>", google_url, d_out$County, d_out$State)
    d_out <- cbind(Find_homes,Location, d_out) %>% 
      select(., -c(County,State)) %>%
      mutate(Population = formatC(Population, big.mark = ",", format = "d")) %>%
      mutate(Median_Income = paste0("$",formatC(Median_Income, big.mark = ",", digits = 2, format="f")))
    return(d_out)
  })
  
  focal_table <- eventReactive(input$find, {
    focal_location = paste(input$county, input$state, sep = ",_") %>%
      str_replace_all(" ", "_") %>%
      tolower()
    dx = readRDS("new_table.rds")
    d_out = dx %>% 
      filter(State == input$state) %>%
      filter(County == input$county)
    d_out$Score = 0.00
    zillowQuery <-
      sprintf("%s-county,-%s",
              tolower(d_out$County),
              tolower(d_out$State))
    url <-
      sprintf("https://www.zillow.com/homes/%s_rb/", zillowQuery)
    Find_homes <- sprintf("<a href='%s'>Find homes</a>", url)
    googleQuery = sprintf("%s+county%s+%s", d_out$County, "%2C", d_out$State) %>%
      str_replace_all(pattern = "_", replacement = "+") %>%
      tolower()
    google_url <-
      sprintf("https://google.com/search?q=%s", googleQuery)
    Location <-
      sprintf("<a href='%s'>%s, %s</a>", google_url, d_out$County, d_out$State)
    d_out <- cbind(Find_homes,Location, d_out) %>% 
      select(., -c(County,State)) %>%
      mutate(Population = formatC(Population, big.mark = ",", format = "d")) %>%
      mutate(Median_Income = paste0("$",formatC(Median_Income, big.mark = ",", digits = 2, format="f")))
    return(d_out)
  })
  
  output$map <- renderPlotly(map())
  output$table <- DT::renderDataTable({
    table()
  }, rownames = FALSE, escape = FALSE, options = list(
    scrollX = TRUE,
    scrollCollapse = TRUE,
    lengthMenu = list(c(10, 20, 50), c('10', '20', '50')),
    pageLength = 10
  ))
  output$focal_table <- DT::renderDataTable({
    focal_table()
  }, rownames = FALSE, escape = FALSE, options = list(
    bFilter = FALSE,
    dom = 't',
    scrollX = TRUE,
    scrollCollapse = TRUE
  ))
  
}

shinyApp(ui = ui, server = server)