//
//  AppLibraryView.swift
//  PlayCover
//

import SwiftUI

struct AppLibraryView: View {
    @EnvironmentObject var appsVM: AppsVM
    @EnvironmentObject var installVM: InstallVM
    @EnvironmentObject var downloadVM: DownloadVM

    @Binding var selectedBackgroundColor: Color
    @Binding var selectedTextColor: Color

    @State private var gridLayout = [GridItem(.adaptive(minimum: 130, maximum: .infinity))]
    @State private var searchString = ""
    @State private var isList = UserDefaults.standard.bool(forKey: "AppLibraryView")
    @State private var selected: PlayApp?
    @State private var showSettings = false
    @State private var showQueue = false
    @State private var showLegacyConvertAlert = false
    @State private var showWrongfileTypeAlert = false

    var body: some View {
        Group {
            if !appsVM.apps.isEmpty || appsVM.updatingApps {
                ScrollView {
                    if !isList {
                        LazyVGrid(columns: gridLayout, alignment: .center) {
                            ForEach(appsVM.filteredApps, id: \.url) { app in
                                PlayAppView(selectedBackgroundColor: $selectedBackgroundColor,
                                            selectedTextColor: $selectedTextColor,
                                            selected: $selected,
                                            app: app,
                                            isList: isList)
                            }
                        }
                        .padding()
                    } else {
                        VStack {
                            ForEach(appsVM.filteredApps, id: \.url) { app in
                                PlayAppView(selectedBackgroundColor: $selectedBackgroundColor,
                                            selectedTextColor: $selectedTextColor,
                                            selected: $selected,
                                            app: app,
                                            isList: isList)
                            }
                            Spacer()
                        }
                        .padding()
                    }
                }
                .onTapGesture {
                    selected = nil
                }
            } else {
                VStack {
                    Text("playapp.noSources.title")
                        .font(.title)
                        .padding(.bottom, 2)
                    Text("playapp.noSources.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("playapp.importIPA") {
                        selectFile()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("sidebar.appLibrary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showSettings.toggle()
                }, label: {
                    Image(systemName: "gear")
                })
                .disabled(selected == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Spacer()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    selectFile()
                }, label: {
                    Image(systemName: "plus")
                        .help("playapp.add")
                })
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Grid View Layout", selection: $isList) {
                    Image(systemName: "square.grid.2x2")
                        .tag(false)
                    Image(systemName: "list.bullet")
                        .tag(true)
                }.pickerStyle(.segmented)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showQueue.toggle()
                }, label: {
                    Image(systemName: "tray")
                })
            }
        }
        .searchable(text: $searchString, placement: .toolbar)
        .onChange(of: searchString, perform: { value in
            uif.searchText = value
            appsVM.fetchApps()
        })
        .onChange(of: isList, perform: { value in
            UserDefaults.standard.set(value, forKey: "AppLibraryView")
        })
        .sheet(isPresented: $showSettings) {
            AppSettingsView(viewModel: AppSettingsVM(app: selected!))
        }
        .sheet(isPresented: $showQueue) {
            QueuesView(selection: QueuesView.Tabs.install)
        }
        .onAppear {
            showLegacyConvertAlert = LegacySettings.doesMonolithExist
        }
        .onDrop(of: ["public.url", "public.file-url"], isTargeted: nil) { (items) -> Bool in
            if let item = items.first {
                if let identifier = item.registeredTypeIdentifiers.first {
                    if identifier == "public.url" || identifier == "public.file-url" {
                        item.loadItem(forTypeIdentifier: identifier, options: nil) { (urlData, _) in
                            Task { @MainActor in
                                if let urlData = urlData as? Data {
                                    let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                                    if url.pathExtension == "ipa" {
                                        uif.ipaUrl = url
                                        installApp()
                                    } else {
                                        showWrongfileTypeAlert = true
                                    }
                                }
                            }
                        }
                    }
                }
                return true
            } else {
                return false
            }
        }
        .alert(isPresented: $showWrongfileTypeAlert) {
            Alert(title: Text("alert.wrongFileType.title"),
                  message: Text("alert.wrongFileType.subtitle"), dismissButton: .default(Text("button.OK")))
        }
        .alert("Legacy App Settings Detected!", isPresented: $showLegacyConvertAlert, actions: {
            Button("button.Convert", role: .destructive) {
                LegacySettings.convertLegacyMonolithPlist(LegacySettings.monolithURL)
                do {
                    try FileManager.default.removeItem(at: LegacySettings.monolithURL)
                } catch {
                    Log.shared.error(error)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("button.Cancel", role: .cancel) {
                showLegacyConvertAlert.toggle()
            }
        }, message: {
            Text("alert.legacyImport.subtitle")
        })
    }

    private func installApp() {
        if let url = uif.ipaUrl {
            QueuesVM.shared.addInstallItem(ipa: url)
        }
    }

    private func selectFile() {
        NSOpenPanel.selectIPA { result in
            if case .success(let url) = result {
                uif.ipaUrl = url
                installApp()
            }
        }
    }
}
